global class Aura_GetCaseInteractionHistory {

    //in the list iterator limit the heap size of the list to 400000 bytes by using 
    //if(Limits.getHeapSize > 400000)
    // stop the iteration and return the list

     public class HistoryWrapper{
        
        @AuraEnabled public String CreatedDateTime;
        @AuraEnabled public String CreatedName;
        @AuraEnabled public String RecordInfo;
        @AuraEnabled public String RecType;
        @AuraEnabled public DateTime RecordDate;
         
    }
    
    @AuraEnabled
    public static List<HistoryWrapper> GetRecords(Id caseid)
    {   
        
        List<HistoryWrapper> historylist = New List<HistoryWrapper>();
        
        
        Case getcase = [Select Id, status, createddate, createdby.name, closeddate, isclosed, closed_case_summary__c,
                         close_case_comments__c, resolution__c, resolved_by__c from case where id = :caseid LIMIT 1];

        //PLEASE NOTE:  The CaseHistory object is not available in unit tests because the case we create in the test is 
        //never committed to the database.  For this reason, the code below related to CaseHistory is not covered.
        //Salesforce does not allow us to create a casehistory in the test and add oldvalue and newvalue.  All the fields
        //are not writeable.
        //make this a list and loop through the case history to get multiple case closures if there are more than one.
        List<CaseHistory> lstcasehist = New List<CaseHistory>();
        lstcasehist =  [SELECT CaseId, Field, NewValue, CreatedBy.Name, CreatedDate FROM CaseHistory WHERE Field = 'Closed_Case_Summary__c'
                                AND CaseId = :caseid];


            //add case create info
            HistoryWrapper casewrapper = New HistoryWrapper();
            
            String cdtime = getcase.CreatedDate.format('yyyy-MM-dd h:mm a');
            String cby = getcase.createdby.name;
            casewrapper.RecordInfo = 'Case created on ' +cdtime +' by ' +cby;
            casewrapper.RecordDate = getcase.createddate;
            historylist.add(casewrapper);
        
            //add case close info
        if(lstcasehist.size() > 0) 
        {
            for(CaseHistory casehist :lstcasehist)
            {
                if(casehist.NewValue != null)
                {
                HistoryWrapper closedwrapper = New HistoryWrapper();
                String closeddate = casehist.createddate.format('yyyy-MM-dd h:mm a');
                closedwrapper.RecordInfo = 'CASE CLOSED ON ' +closeddate +' by ' +casehist.createdby.name +'\n'+'\n';
                closedwrapper.RecordInfo += 'Close Summary: ' +casehist.NewValue +'\n'+'\n';
                closedWrapper.RecordDate = casehist.createddate;
                historylist.add(closedwrapper);
                }
            }

        }

                         

        List<Task> tasklist = New List<Task>();
        tasklist = gettasklist(caseid);
        //system.debug('tasklist size is ' +tasklist.size());
        
        List<CaseComment> commentlist = New List<CaseComment>();
        commentlist = getcommentlist(caseid);

        List<ServiceAppointment> salist = New List<ServiceAppointment>();
        salist = getappointmentlist(caseid);
        
       // List<ServiceAppointment> appointmentlist = getappointmentlist(caseid);

        

        If(commentlist.size() > 0)
        {

            for(CaseComment cc :commentlist)
            {
                HistoryWrapper hw = New HistoryWrapper();
                String formatteddate = cc.CreatedDate.format('yyyy-MM-dd h:mm a');
                hw.CreatedName = cc.CreatedBy.Name;
                hw.CreatedDateTime = formatteddate;
                hw.RecordInfo = 'Case Comment created by ' +hw.CreatedName +' on ' +hw.CreatedDateTime +'\n'+'\n';
                if(cc.IsPublished==false)
                {
                    String internal;
                    internal = '*******INTERNAL Comments*******' +'\n';
                    if(cc.CommentBody != null && cc.CommentBody.contains('<br/>'))
                    {
                        String thisbody;
                        thisbody = cc.CommentBody.replaceAll('<br/>', '\n');
                        internal += thisbody;
                    }
                    else{
                        internal += cc.CommentBody;
                    }
                    hw.RecordInfo += internal +'\n' +'\n';
                }
                else {
                
                    String external;
                    if(cc.CommentBody != null && cc.CommentBody.Contains('<br/>'))
                    {
                        external = cc.CommentBody;
                        external = external.replace('<br/>', '\n');
                        hw.RecordInfo += external;
                    }
                    else {
                        hw.RecordInfo += cc.CommentBody;
                    }
                
                }
            
                hw.RecordDate = cc.CreatedDate;  //the wrapper recorddate field is for sorting the list

                historylist.add(hw);
            }

        }

        if(tasklist.size() > 0)
        {
            for(Task t :tasklist)
            {   
                HistoryWrapper history = New HistoryWrapper();

                String formatteddate = t.CreatedDate.format('yyyy-MM-dd h:mm a');
                String recordbody;
                String line1;
                history.CreatedDateTime = formatteddate;
                history.CreatedName = t.CreatedBy.Name;
                line1 = 'Task created by ' +history.CreatedName +' on ' +history.CreatedDateTime;
                
                if(t.subject != null && !t.subject.contains('Chat'))
                {
                    recordbody = line1 + '\n'+'\n';
                    if(t.Task_Origin__c != null)
                    { recordbody += 'Origin:  ' +t.Task_Origin__c +'\n'+'\n'; }
                    else
                    {  recordbody += 'Origin: ' +'\n'+'\n'; }

                    if(t.description != null)
                    { recordbody += 'Comments:  ' +t.description +'\n'+'\n'; }
                    else {
                      recordbody += 'Comments: ' +'\n'+'\n';
                    }
                    
                    if(t.Internal_Notes__c != null)
                    {
                        recordbody +='*******INTERNAL Comments*******'+'\n';
                        recordbody += t.Internal_Notes__c +'\n' +'\n';
                    }
                }
                else {
                    String chaturl1 = t.RC_Call_Recording__c.remove('<a href=');
                    String chaturl2 = chaturl1.remove('>ACD Recording</a>');
                    Integer duration;
                    if(t.CallDurationInSeconds != null && t.CallDurationInSeconds > 0)
                    { duration = t.CallDurationInSeconds/60; }
                    else {
                      duration = 0;
                    }

                    recordbody = line1 +'\n'+'\n';
                    recordbody += 'Ring Central Task Subject: ' +t.Subject +'\n';
                    recordbody += 'Duration (Minutes): ' +duration +'\n';
                    recordbody += 'ACD Recording: ' +chaturl2 +'\n'+'\n';
                }

                history.RecordInfo = recordbody;
                history.RecordDate = t.CreatedDate;

                //system.debug(history);
           
                historylist.add(history);
                
            }
        }

        if(salist.size() > 0)
        {
            for(ServiceAppointment sa :salist)
            {   
                HistoryWrapper wrapper = New HistoryWrapper();
                String cdate = sa.CreatedDate.format('yyyy-MM-dd h:mm a');
                wrapper.CreatedDateTime = cdate;
                String csstart;
                String actualst;
                String actualend;
                if(sa.ActualStartTime != null)
                { actualst = sa.ActualStartTime.format('yyyy-MM-dd h:mm a'); }
                else {
                  actualst = '';
                }
                if(sa.ActualEndTime != null)
                { actualend = sa.ActualEndTime.format('yyyy-MM-dd h:mm a'); }
                else {
                  actualend = '';
                }
                if(sa.SchedStartTime != null)
                { csstart = sa.SchedStartTime.format('yyyy-MM-dd h:mm a'); }
                else {
                  csstart = 'Not scheduled';
                }
                String csend;
                if(sa.SchedEndTime != null)
                { csend =  sa.SchedEndTime.format('yyyy-MM-dd h:mm a'); }
                else {
                    csend = 'Not scheduled';
                }
                String assigned = sa.Technician_Assigned__r.Name;
                wrapper.CreatedName = sa.CreatedBy.Name;
                String recordbody;
                recordbody = 'Service Appointment created by ' +wrapper.CreatedName +' on ' +wrapper.CreatedDateTime +'\n'+'\n';
                recordbody += 'Scheduled Start: ' +csstart +'\n';
                recordbody += 'Scheduled End: ' +csend +'\n';
                recordbody += 'Technician Assigned: ' +assigned +'\n';
                recordbody += 'Actual Start: ' +actualst +'\n';
                recordbody += 'Actual End: ' +actualend +'\n';
                recordbody += 'Appointment Status: ' +sa.status;

                wrapper.RecordInfo = recordbody;
                wrapper.RecordDate = sa.CreatedDate;
                historylist.add(wrapper);
            }
        }

        

        List<HistoryWrapper> sortedlist = New List<HistoryWrapper>();

        if(historylist.size() > 0)
        { sortedlist = SortHistoryList(historylist); }
        else {
            
        
            HistoryWrapper wrapper = New HistoryWrapper();
            wrapper.RecordInfo = 'There is no case interaction history to display.';
            sortedlist.add(wrapper);
        }

        return sortedlist;

    }
    
    
    @AuraEnabled
    public static List<Task> gettasklist(Id caseid)
    {
        system.debug('inside gettasklist');
        List<Task> lsttask = New List<Task>();
        lsttask = [Select Id, WhatId, Description, Subject,Task_Origin__c, CreatedBy.Name, CreatedDate, RC_Call_Recording__c,
                   CallDurationInSeconds, Case_Product_Type__c, Issue_Type__c, Issue_Sub_Type__c, Issue_Details__c, internal_notes__c, lastmodifieddate from 
                   Task where WhatId = :caseid AND (NOT Subject like 'Voice Call%') AND (not Subject like 'Email:%')
							ORDER BY CreatedDate DESC, LastModifiedDate DESC];

        return lsttask;
        
    }

    @AuraEnabled 
    public static List<CaseComment> getcommentlist(Id caseid) 
    {
        system.debug('inside getcommentlist');
        List<CaseComment> lstcomments = New List<CaseComment>();
        lstcomments = [Select Id, ParentId, CommentBody, CreatedBy.Name, CreatedDate, isPublished, LastModifiedDate, isDeleted
                       from CaseComment where ParentId = :caseid AND isDeleted = false ORDER BY CreatedDate DESC, LastModifiedDate DESC ];

        return lstcomments;
    }

    @AuraEnabled 
    public static List<ServiceAppointment> getappointmentlist(Id caseid) 
    {   
        system.debug('inside getappointmentlist');
        List<ServiceAppointment> lstsvcappt = New List<ServiceAppointment>();
        lstsvcappt = [Select Id, case__c, createddate, createdby.Name, LastModifiedDate, schedstarttime, schedendtime, 
        ActualStartTime, ActualEndTime, Status, technician_assigned__r.name from 
        serviceappointment where case__c = :caseid ORDER BY CreatedDate DESC, LastModifiedDate DESC ];

        return lstsvcappt;
    } 

    @AuraEnabled
    public static List<HistoryWrapper> SortHistoryList(List<HistoryWrapper>historyList) {
			
		Map<DateTime, List<HistoryWrapper>> historyMap = new Map<DateTime, List<HistoryWrapper>>();
		
		// Iterate over history items
		for (HistoryWrapper history : historyList) {
			
			if (historyMap.containsKey(history.RecordDate)) {
				historyMap.get(history.RecordDate).add(history);
			} else {
				historyMap.put(history.RecordDate, new List<HistoryWrapper> { history });
			}
			
		}
		
		// Get and sort date key values
		List<DateTime> dateKeys = new List<DateTime>(historyMap.keyset());
		dateKeys.sort();
		
		historyList.clear();
		
		// Reverse iterate over date keys and get list items
		Integer ndx = dateKeys.size();
		while (ndx > 0) {
			ndx--;
			historyList.addAll(historyMap.get(dateKeys[ndx]));
		}

        return historyList;
	}
}