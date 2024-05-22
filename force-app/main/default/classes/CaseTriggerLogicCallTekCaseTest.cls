@isTest
public class CaseTriggerLogicCallTekCaseTest {
    
    static testmethod void testPopulateCallTekCasesNotContracted(){

        Id accrecid = Utilities.RecordTypeNametoId('Account', 'Hospitality Site');
        
        Account ncacct = New Account(Name = 'Not Contracted Account', Account_Status__c = 'Prospect',
                recordtypeid = accrecid);
        insert ncacct;

        ServiceContract ncsc = New ServiceContract(Name = 'Legacy No Warranty', startdate = system.today().addYears(-50),
                        enddate = system.today().addYears(-49), AccountId=ncacct.id);
        insert ncsc;

        Entitlement ncent = New Entitlement(Name = 'Service & Maintenance', AccountId=ncacct.id, startdate=system.today().addYears(-20),
                           enddate=system.today().addYears(20), ServiceContractId=ncsc.id);
        insert ncent;
        
        Account acct = CreateTestRecords.DefaultHospitalityAccount();
        Id acctid = acct.id;

        Asset bbasset = New Asset(Name = 'Interactive Product Parent', accountid = acctid, status = 'Installed Activated',
                                  Quantity = 50);

        insert bbasset;

        AppConfig__c appconfig = New AppConfig__c();
        appconfig.name = 'Global';
        appconfig.Base_Service_Contract__c = ncsc.id;
        appconfig.Base_SLA__c = ncent.id;
        insert appconfig;

        test.startTest();

        Account getaccount = [Select Id, site_id__c from Account where id = :acctid LIMIT 1];

        Case c = New Case();
        c.origin = 'CallTek';
        c.subject = 'Testing the Code for handling CallTek Cases';
        c.case_product_type__c = 'Broadband';
        c.Issue_Type__c = 'Customer Devices - GIA';
        c.Issue_Sub_Type__c = 'Laptop/PC Device - GIA';
        c.site_id__c = getaccount.Site_ID__c;
        c.Customer_Name__c = 'John Smith';
        c.Call_Back_Number__c = '605-988-1404';
        c.Customer_Room_Number__c = '901';
        c.Notes__c = 'Testing the creation of a Task to be linked to the case';
        insert c;

        Case getcase = [Select Id, account.name, EntitlementId, Service_Contract_Name__c from Case where id = :c.id LIMIT 1];
        system.debug('getcase entitlement id is ' +getcase.entitlementid);
        system.debug('getcase account name is ' +getcase.account.name);

        test.stopTest();

        system.assert(getcase.entitlementid != null);

    }

    static testmethod void testPopulateCallTekCasesWithBroadband(){

        Id accrecid = Utilities.RecordTypeNametoId('Account', 'Hospitality Site');
        
        Account acct = CreateTestRecords.DefaultHospitalityAccount();
        Id acctid = acct.id;

        Asset bbasset = New Asset(Name = 'Broadband Product Parent', accountid = acctid, status = 'Installed Activated',
                                  Quantity = 50);

        insert bbasset;

        ServiceContract sc = New ServiceContract(Name='Warranty Time & Materials', Accountid = acctid, startdate = system.today().addMonths(-3),
                              enddate = system.today().addMonths(12), Product_Inventory__c = bbasset.id);
        insert sc;

        Entitlement ent = New Entitlement(Name='Time & Materials', accountid = acctid, ServiceContractId=sc.id,
                          startdate = system.today().addmonths(-3), enddate = system.today().addMonths(12), AssetId=bbasset.id);
        insert ent;

        test.startTest();

        Account getaccount = [Select Id, site_id__c from Account where id = :acctid LIMIT 1];

        Case c = New Case();
        c.origin = 'CallTek';
        c.subject = 'Testing the Code for handling CallTek Cases';
        c.case_product_type__c = 'Broadband';
        c.Issue_Type__c = 'Customer Devices - GIA';
        c.Issue_Sub_Type__c = 'Laptop/PC Device - GIA';
        c.site_id__c = getaccount.Site_ID__c;
        c.Customer_Name__c = 'John Smith';
        c.Call_Back_Number__c = '605-988-1404';
        c.Customer_Room_Number__c = '901';
        c.Notes__c = 'Testing the creation of a Task to be linked to the case';
        insert c;

        Case getcase = [Select Id, account.name, Entitlement.name, Service_Contract_Name__c, asset.Name from Case where id = :c.id LIMIT 1];
        system.debug('getcase entitlement name is ' +getcase.entitlement.name);
        system.debug('getcase account name is ' +getcase.account.name);
        system.debug('getcase product inventory is ' +getcase.asset.name);

        test.stopTest();

        system.assert(getcase.entitlementid != null);

    }

}