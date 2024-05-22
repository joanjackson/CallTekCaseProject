/*
jjackson 5/2024 CallTek case project:  When CallTek cases come into Salesforce, run code to populate
entitlement, service contract, and product inventory on these cases after insert.
jjackson 1/2023:  For test runs, moved call to CreateCaseComments from behind the recursion block because the test
wasn't hitting the code.
jjackson 2/2022:  include this with deployment of Clarify EOL code because updates were made in
EmailUtilities.cls and the signature for EmailUtilities.NotifyThirdPartyCaseQueueMembers(trigger.new, trigger.oldMap, useremail)
now includes a string for current user email address.

*/

trigger StandardCaseTriggerForContractedFieldService on Case (after insert, after update) {
	
	try{ 
    	if(AppConfig__c.getValues('Global').BlockTriggerProcessing__c) {
    		return;
    	} else if(CaseAfterTrigConfig__c.getValues('Global').BlockTriggerProcessing__c) {
			return; 
		}
    }
    catch (Exception e) {}
	
		
	Id recid = Utilities.RecordTypeNameToId('Case', 'Contracted Field Service');
	List<Case> lstcfscasebeforeinsert = New List<Case>();
	List<Case> lstcalltekcases = New List<Case>();
	Map<Id,Case> mpcalltekcases = New Map<Id,Case>();
	List<Case> lsttrigcases = New List<Case>();
	//jjackson 1/2022 BUG-01463  pass user emailaddress into NotifyThirdPartyCaseQueueMembers so current user can receive the email
	String useremail = UserInfo.getUserEmail();
	system.debug('useremail is ' +useremail);
	
	if(trigger.isInsert)
	{	
		//jjackson 5/2024 if the case is not a mass case and the origin is CallTek create a separate case list
		//jjackson 9/2021 only call this method if mass cases aren't being loaded
		for(Case c :trigger.new)
		{
			if(c.Mass_Case__c == false)
			{	
				if(c.origin != 'CallTek')
				{ lstcfscasebeforeinsert.add(c); }

				if(c.origin == 'CallTek')
				{ mpcalltekcases.put(c.id, c);  }

				system.debug(c.id);
				system.debug(c.Site_ID__c);
				system.debug(c.Case_Product_Type__c);
			}
			
				
				//for normal cases that do not have an origin of CallTek, create a case trigger list
				//to pass into the methods that do not pertain to calltek cases
				if(c.origin != 'CallTek')
				{ lsttrigcases.add(c); }
			
		}

		if(lstcfscasebeforeinsert.size() > 0)
		{ CaseTriggerLogic.PopulateSpecialInstructions(lstcfscasebeforeinsert); }

		if(mpcalltekcases.size() > 0)
		{ CaseTriggerLogicCallTekCases.populateCallTekCase(mpcalltekcases); }

		//Rekha Asani 03/2022 This method is to create Case Comment record with an email body received from dynatrace.
        DynatraceEmailToCaseHelper.createCaseComments(trigger.new);
	}
	
	if(trigger.isUpdate)
	{
		//jjackson  Get contract field service cases in a list
		List<Case> lstcontractedfieldservice = New List<Case>();
		for(Case c :trigger.new)
		{
			if(c.recordtypeid == recid)
			{  lstcontractedfieldservice.add(c); }
		}

		if(test.isRunningTest())
		{
			CaseTriggerLogic.CreateCaseCommentfromComments(lsttrigcases, trigger.oldMap);
		}
		else 
		{	
		
		 	if(triggerRecursionBlock.flag == true)
		 	{ 
		 		system.debug('inside after update recursion block');
		 		CaseTriggerLogic.CreateCaseCommentfromComments(lsttrigcases, trigger.oldMap);
			
				if(lstcontractedfieldservice.size() > 0)
				{ EmailUtilities.NotifyThirdPartyCaseQueueMembers(lstcontractedfieldservice, trigger.oldMap, useremail); }
	        
				triggerRecursionBlock.flag = false;
		 	}
		}
		 
		 Id recid = Utilities.RecordTypeNameToId('Case', 'Contracted Field Service');
		 List<Id> lstclosedcases = new List<Id>();
		 
		 for(Case trig :trigger.new)
		 {
		 	if(trig.recordtypeid == recid )
		 	{
		 		if(trig.status.contains('Closed') && !trigger.oldmap.get(trig.id).status.Contains('Closed'))
		 		{  lstclosedcases.add(trig.id);  }
		 	}
		 }
		 
		 if(lstclosedcases.size() > 0)
		 {  CustomCaseLogic.GetCaseInteractionHistory(lstclosedcases, null);  }
				
		
	}
	

    
}