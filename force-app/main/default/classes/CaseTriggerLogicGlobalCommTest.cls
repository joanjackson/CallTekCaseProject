/*
Code coverage for CaseTriggerLogicGlobalCommunity.cls, which was created for the Experience Cloud customer portal.
91% covered.

Joan Jackson, Sonifi Solutions
August 2022
*/
@isTest
public without sharing class CaseTriggerLogicGlobalCommTest {

public static Account nonconAcct = CreateDummyAccount();
public static ServiceContract basesc = CreateDefaultSC(nonconAcct.Id);
public static Entitlement baseent = CreateBaseEntitlement(basesc.Id, nonconAcct.Id);

static testmethod void testpopulateExperienceCloudCase()
{

    Account acc = CreateTestRecords.DefaultHospitalityAccount();
    Id accid = Utilities.RecordTypeNameToId('Account', 'Hospitality Site');
    Account notcontracted = New Account(Name='Not Contracted Account', recordtypeid = accid, physical_country__c = 'USA');
    insert notcontracted;
    Product2 p2 = New Product2(Name='FTG Product Parent', productcode='TestCC-10005', isActive=true, Family='FTG');
    insert p2;
    CaseProductTypes__c cpt = New CaseProductTypes__c(Name='FTG Product Parent', Product_Inventory__c='FTG');
    insert cpt;
    EC_Case_Product_Types__c eccpt = New EC_Case_Product_Types__c(Name='ECCPT-01', Experience_Cloud_Case_Value__c = 'TV Channels',
                             Case_Product_Type__c = 'FTG');
    insert eccpt;

    Id hospconid = Utilities.RecordTypeNameToId('Contact', 'Hospitality Contact');
    Contact testcon = New Contact(firstname='Joe', lastname='Tiddlywinks', Accountid = notcontracted.id, title='GM',
                                   recordtypeid = hospconid, Status__c='Active' );
    insert testcon;

    Contact testcon2 = New Contact(firstname='Joe', lastname='Tiddlytown', Accountid = acc.id, title='GM',
                                   recordtypeid = hospconid, Status__c='Active' );
    insert testcon2;
    

    Asset a = New Asset(Name='FTG Product Parent', accountid = acc.id, status='Installed Activated', product2id = p2.id,
    Total_Room_Count__c = 200, Quantity=200, service_start_date__c = system.today());
    insert a;
    ServiceContract sc = New ServiceContract(Name='Test ServiceContract', Accountid=acc.id, StartDate=system.today(), Enddate=system.today().addDays(365),
                         Term=12, Product_Inventory__c=a.id);
    insert sc;
    Entitlement e = New Entitlement(Name='Test Entitlement', Accountid=acc.id,ServiceContractId=sc.id, startdate=system.today().addDays(-365),
                                   enddate=system.today().addDays(365), assetid = a.id);
    insert e;

    ServiceContract notconsc = New ServiceContract(Name='Legacy No Warranty', Accountid=notcontracted.id, StartDate=system.today().addDays(-450), Enddate=system.today().addDays(-365));
    insert notconsc;

    Entitlement notcone = New Entitlement(Name='Service & Maintenance', Accountid=notcontracted.id,ServiceContractId=notconsc.id, startdate=system.today().addDays(-365),
                                   enddate=system.today().addDays(365));
    insert notcone;

    AppConfig__c appc = New AppConfig__c(Name='Global', Not_Contracted_Entitlement__c = notcone.id, Base_Service_Contract__c = notconsc.id);
    insert appc;

    test.startTest();

    Id caserecid = Utilities.RecordTypeNameToId('Case', 'Support Case');
    Case c = New Case(recordtypeid=caserecid, origin='SONIFI Portal', accountid=acc.id, Impacted_Product_Type__c = 'TV Channels',
            contactid = testcon2.id );
    insert c;

    Case testcase = [Select Id, assetid, entitlementid from Case where id = :c.id LIMIT 1];
    system.debug('testcase asset id is ' +testcase.assetid);
    system.assert(testcase.assetid == a.id);
    system.assert(testcase.entitlementid == e.id);

    e.enddate = system.today().addDays(-10);
    update e;

    Case nextcase = New Case(recordtypeid=caserecid, origin='SONIFI Portal', accountid=acc.id, Impacted_product_type__c = 'TV Channels');
    insert nextcase;

    test.stopTest();

}

static testmethod void testpopulateExperienceCloudCaseNoAssets()
{
    //Account acc = CreateTestRecords.DefaultHospitalityAccount();
    Product2 p2 = New Product2(Name='FTG Product Parent', productcode='TestCC-10005', isActive=true, Family='FTG');
    insert p2;
    CaseProductTypes__c cpt = New CaseProductTypes__c(Name='FTG Product Parent', Product_Inventory__c='FTG');
    insert cpt;

    Account notcontracted = CreateDummyAccount();
    ServiceContract sc = CreateDefaultSC(notcontracted.id);
    Entitlement ent = CreateBaseEntitlement(sc.id, notcontracted.id);
    Id hospconid = Utilities.RecordTypeNameToId('Contact', 'Hospitality Contact');
    Contact newcon = New Contact(firstname='Joe', lastname='Dumbledorf', Accountid = notcontracted.id, title='GM',
                      recordtypeid = hospconid, Status__c='Active' );
    insert newcon;

    system.debug('ent id is ' +ent.id);

    AppConfig__c appconfig = New AppConfig__c(Name='Global', Base_Service_Contract__c = sc.id, Not_Contracted_Entitlement__c=ent.id );
    insert appconfig;
    
    test.startTest();

    Id caserecid = Utilities.RecordTypeNameToId('Case', 'Support Case');
    Case c = New Case(recordtypeid=caserecid, origin='SONIFI Portal', accountid=notcontracted.id, case_product_type__c = 'FTG',
                 contactid = newcon.id);
    insert c;

    Case testcase = [Select Id, assetid, entitlementid from Case where id = :c.id LIMIT 1];
    system.debug('testcase asset id is ' +testcase.assetid);
    
    system.debug(testcase.entitlementid==ent.id);
    system.assert(testcase.assetid==null);

    test.stopTest();
}

@isTest 
static Account CreateDummyAccount()
{
    Id accrectype = Utilities.RecordTypeNameToId('Account', 'Hospitality Site');
    Account scac = New Account(Name='Not Contracted Account', account_status__c = 'Prospect', recordtypeid = accrectype,
                               Physical_Country__c = 'USA');
    insert scac;
    return scac;
}


static ServiceContract CreateDefaultSC(Id accid)
{   
    ServiceContract sc = New ServiceContract(Name='Legacy No Warranty', AccountId = accid, startdate = system.today().addMonths(-12),
                                             enddate = system.today().addMonths(-2));
    insert sc;

    ServiceContract returnsc = [Select Id from ServiceContract where Id = :sc.id LIMIT 1];
    return returnsc;

}

static Entitlement CreateBaseEntitlement(Id scid, Id accid)
{
    Entitlement ent = New Entitlement(Name='Service & Maintenance', Accountid = accid, servicecontractid = scid,
                      startdate = system.today().addMonths(-12), enddate = system.today().addMonths(12));
    insert ent;
    return ent;
}
    
}