

Case c = New Case();
c.origin = 'CallTek';
c.subject = 'Testing the Code for handling CallTek Cases';
c.case_product_type__c = 'Broadband';
c.Issue_Type__c = 'Customer Devices - GIA';
c.Issue_Sub_Type__c = 'Laptop/PC Device - GIA';
c.site_id__c = '0302652';
c.Customer_Name__c = 'John Smith';
c.Call_Back_Number__c = '605-988-1404';
c.Customer_Room_Number__c = '901';
c.Notes__c = 'Testing the creation of a Task to be linked to the case';
insert c;
