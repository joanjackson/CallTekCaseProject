/**********************************************************************************************
jjackson 5/2024: CallTek case project -- excluding cases with origin of CallTek from most of
these methods.  There is a separate trigger logic class to handle the CallTek cases because it is
a Global class.
jjackson Sonifi Solutions 12/1/2021
//Made changes to this trigger to only process cases through the trigger code if they are not
//dataloaded cases; in other words, the mass case create field = false.  Dataloading
//cases was becoming impossible due to the amount of code that gets processed for each one;
//the mass case checkbox now will allow loading of cases without time out errors but the
//input spreadsheet will have to contain an id for work type, etc.
//Old trigger code no longer needed has been commented out and some of the methods here have
//been re-ordered to make it more streamlined.  
//
// Filename:     StandardCaseTrigger
// Version:      0.0.1
// Author:       Etherios
// Date Created: 8/6/2013
// Description:  Trigger on the Case object.
//  
// Copyright 2013 Etherios. All rights reserved. Customer confidential. Do not distribute.
// *********************************************************************************************
// *********************************************************************************************/

trigger StandardCaseTrigger on Case (before insert, before update) {

    // Check for trigger processing blocked by custom setting
    try{ 
        if(AppConfig__c.getValues('Global').BlockTriggerProcessing__c) {
            return;
        } else if(CaseTriggerConfig__c.getValues('Global').BlockTriggerProcessing__c) {
            return; 
        }
    }
    catch (Exception e) {}

    Map<Id,String> casesServiceContractMap = New Map<Id,String>();
    Id rectypeid = Utilities.RecordTypeNameToId('Case', 'Contracted Field Service');
    Id recsuppid = Utilities.RecordTypeNametoId('Case', 'Support Case');
    List<Case> lstcaseinsert = new List<Case>();
    List<Case> lstcaseportal = new List<Case>();  //for cases created in Experience cloud by customers 8/2022
    List<Case> lstdispatchedcases = New List<Case>();
    List<Case> lstcalltek = New List<Case>();
    
        
    // Check for NEW trigger
    if (Trigger.isInsert) 
    {   
                  
         //jjackson 9/2021 do not send mass cases through all the trigger methods.  It causes
        //dataloads to bomb.  Things like service territory and work type can be added to the
        //dataload spreadsheet
        //jjackson 9/2022:  separate cases that are coming from the experience cloud portal.  They do not
        //go through all the other code; only the populateExperienceCloudCase method.
        for(Case c :trigger.new)
        {
                
                if(c.recordtypeid == recsuppid && c.mass_case__c == false && c.origin != 'CallTek')
                {  lstcaseinsert.add(c); }

                if(c.recordtypeid == recsuppid && c.mass_case__c == false && c.origin == 'SONIFI Portal')
                {  lstcaseportal.add(c); }
        }
       
        system.debug('lstcaseinsert size is ' +lstcaseinsert.size());

        if(test.isRunningTest())
        {
            if(lstcaseportal.size() > 0)
            {
                List<Case> lstsetcasefields = New List<Case>();
                lstsetcasefields = CaseTriggerLogicGlobalCommunity.populateExperienceCloudCase(lstcaseportal); 
                CaseTriggerLogic.PopulateFieldResponseTimeCase(lstsetcasefields); //we need this here to populate response time/synopsis
                CaseTriggerLogic.GetSpecialConsiderationMilestone(lstsetcasefields);
            }

        }


        if(lstcaseinsert.size() > 0)
        {
            for(Case c :lstcaseinsert)
            {
                if(c.recordtypeid != rectypeid)
                {   if (c.Date_Time_Initiated__c == null)
                    { c.Date_Time_Initiated__c = DateTime.now(); }
                }
            }

            //jjackson exclude calltek cases from all these methods
            //jjackson 10/2016 verify new support cases contain customer name and role
            CaseTriggerLogic.VerifyCustomerNameRole(lstcaseinsert);
            if(CaseTriggerLogic.isFirstTime){
                CaseTriggerLogic.isFirstTime = false;
            	CaseTriggerLogic.PopulateTerritoryandWorkType(lstcaseinsert, String.valueOf(Trigger.operationType));
            }
            CaseTriggerLogic.PopulateFieldResponseTimeCase(lstcaseinsert);
            CaseTriggerLogic.GetSpecialConsiderationMilestone(lstcaseinsert);
        
            //jjackson 10/2016 this method pertains to Hyatt email notifications under Hyatt MSA    
            CaseTriggerLogic.GetCaseEmailCriteria(lstcaseinsert, trigger.oldmap);
            //Rekha Asani 02/2022 this method populates account name field on case from the email body (site Id footer) for the email coming from dynatrace
            DynatraceEmailToCaseHelper.poupulateCaseDetails(lstcaseinsert);

        }
            
    } //end if trigger isinsert
    
            
    if(trigger.IsUpdate)
    {       
            //jjackson 5/2017, if a case being updated is a single digits BAP case, check to make sure
            //the case ownership hasn't changed.
            List<Case> lstcases = New List<Case>();
            List<Case> lstthirdparty = New List<Case>();
            List<Case> lstpopulatecase = New List<Case>();
            List<Case> lststatuschange = New List<Case>();
            List<Case> lsthyattevaluate = New List<Case>();
            Map<Id, List<Case>> statusChangeCaseMap = new Map<Id, List<Case>>();
            List<Case> lstdispatchedcases = New List<Case>();
            List<Case> lstprioritychd = New List<Case>();
            
            for(Case c : trigger.new)
            {
                if(c.mass_case__c == false)
                {
                    if(c.single_digits_case_id__c != null)
                    {  lstcases.add(c); }
                    else 
                    {   //jjackson 5/2019 FSL Project:  Look for cases that are being dispatched to or undispatched from
                    //the Dispatch queue for creating service appointments
                    if(c.send_to_dispatch_queue__c == true & trigger.oldMap.get(c.id).send_to_dispatch_queue__c == false )
                    {  lstcases.add(c); }
                    
                    if(c.send_to_dispatch_queue__c == false && trigger.oldMap.get(c.id).send_to_dispatch_queue__c == true)
                    {
                        lstcases.add(c);
                    }
                    }
            
                
                    if(c.recordtypeid == rectypeid)
                    {
                        lstthirdparty.add(c);
                    }
            
                    if((c.recordtypeid == rectypeid || c.recordtypeid == recsuppid) && c.origin != 'CallTek')
                    {
                       lstpopulatecase.add(c);

                    }

                    if(c.dispatched__c == true && trigger.oldmap.get(c.id).dispatched__c == false && c.recordtypeid == recsuppid)
                    {
                        lstdispatchedcases.add(c);
                    }

                    if(c.recordtypeid == recsuppid && c.origin != 'CallTek')
                    {   lsthyattevaluate.add(c); }

                    if(c.dispatched__c == true && c.priority != trigger.oldmap.get(c.id).priority
                        && c.recordtypeid == recsuppid)
                    {
                        lstprioritychd.add(c);
                    }
                

                    if(c.origin != 'CallTek' && c.recordtypeid == recsuppid && c.Mass_Case__c == false && c.status != trigger.oldmap.get(c.id).status)
                    {
                                                
                        if (statusChangeCaseMap.containsKey(c.AccountId)) {
                        statusChangeCaseMap.get(c.AccountId).add(c);
                        } else {
                        statusChangeCaseMap.put(c.AccountId, new List<Case> { c });
                        }   

                        lststatuschange.add(c);
                    }
                }//end if mass_case__c == false
            
            } //end for loop trigger.new
            
            //system.debug('lstthirdparty size is ' +lstthirdparty.size() +' in the trigger.');
            
            //jjackson 5/2019 FSL Project:  The CheckCaseOwner method has been updated to change ownership of the
            //case to the Dispatch queue under certain conditions
            
            
            
            if(lstpopulatecase.size() > 0 && CaseTriggerLogic.isFirstTime)
            { 
                CaseTriggerLogic.isFirstTime = false;
                CaseTriggerLogic.PopulateTerritoryandWorkType(lstpopulatecase, String.valueOf(Trigger.operationType)); 
            }

            List<Case> lstcannotreopen = New List<Case>();
            for(Case c :trigger.new)
            {   
                if(trigger.oldMap.get(c.id).status == 'Closed' && c.status != 'Closed' && c.Mass_Case__c == false)
                {   lstcannotreopen.add(c); }
                
            }

            if(lstcannotreopen.size() > 0)
            {   CaseTriggerLogic.PreventCaseReOpen(lstcannotreopen, trigger.oldMap);  }// jjackson 1/2023}
            
            if(lstcases.size() > 0)
            {  CaseTriggerLogic.CheckCaseOwner(lstcases, trigger.oldmap);  }
            
            
            
            CaseTriggerLogic.DispatchThirdPartyCases(lstthirdparty, 'update', trigger.oldMap);
        
            //jjackson 10/2016 these methods pertain to notification emails for Hyatt MSA cases
            CaseTriggerLogic.GetCaseEmailCriteria(lsthyattevaluate, trigger.oldmap);
            CaseTriggerLogic.UpdateEmailFrequencyAfterSeverityChange(lsthyattevaluate, trigger.oldmap);
            CaseTriggerLogic.StopOrRestartEmailNotification(lsthyattevaluate, trigger.oldmap);
        
            //jjackson all the code below is used to identify Hilton SLA cases that within 2 hours of milestone violation
            List<Case> casenotificationslist = New List<Case>();
            
            for(Case caserec : trigger.new)
            {
                if(caserec.mass_case__c == false)
                {
                    if((caserec.nearing_expiration__c == true && trigger.oldmap.get(caserec.id).nearing_expiration__c == false) &&
                    caserec.recordtypeid == recsuppid && caserec.issue_type__c != null && (!caserec.issue_type__c.Contains('Project')|| caserec.mass_case__c == false)) //don't send notification for project cases
                    {  casenotificationslist.add(caserec);  }
                }
            }
            
            if(casenotificationslist.size() > 0)
            { EmailUtilities.PendingCaseViolationNotification(casenotificationslist);  } 
            
            //jjackson End of case milestone violation code for Hilton SLA

            
            //process case dispatches
            if(lstdispatchedcases.size() > 0)
            {
                    CaseTriggerLogic.dispatchCases(lstdispatchedcases);
                    CaseTriggerLogic.PopulateFieldResponseTimeCase(lstdispatchedcases);
                    CaseTriggerLogic.GetSpecialConsiderationMilestone(lstdispatchedcases);
                
            }

            //process case status changes
            if(statuschangecasemap.size() > 0)
            {   
                casesServiceContractMap = CustomCaseLogic.casesServiceContracts(lststatuschange);
                if(casesServiceContractMap.size() > 0)
                {   CustomCaseLogic.processStatusChange(statusChangeCaseMap, casesServiceContractMap); }
            }

            //process case priority changes
            if(lstprioritychd.size() > 0)
            {
                CaseTriggerLogic.PopulateFieldResponseTimeCase(lstprioritychd);
                CaseTriggerLogic.GetSpecialConsiderationMilestone(lstprioritychd);
            }

        
    } //end if trigger is update
    

   
    
 }