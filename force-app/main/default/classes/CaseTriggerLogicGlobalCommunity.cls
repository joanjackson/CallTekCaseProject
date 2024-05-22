/*
jjackson 9/2022 BUG-02012:  Added code to below method that will create a non-contracted support case if
matching assets for the case product type are not found.  Deployed to eclouddev on 9/7/2022 via vscode.
jjackson 8/2022 BUG-02012:  New method for support cases that are created by customers using
Experience Cloud.  Based on the Case Product Type they choose and the Account associated with the
case, find the product inventory parent that matches the product type and link the product inventory,
entitlement, and service contract to the case.

Joan Jackson 8/22/2022 Experience Cloud Project
Sonifi Solutions

*/
Global without sharing class CaseTriggerLogicGlobalCommunity {

    //jjackson 8/10/22 -- run before insert
	//must create support cases through an execute anonymous script to avoid page layout required fields
	global static List<Case> populateExperienceCloudCase(List<Case> lsttrigger)
	{	
		system.debug('*********BEGIN PopulateExperiencecloudCase************');
        
        Map<Id,Case> mpprocesscase = New Map<Id,Case>();
		Map<Id,String> mpcaseproducts = New Map<Id,String>();
		Map<String,String> mpecproducttypes = New Map<String,String>();
		Set<Id> setaccid = New Set<Id>();
		Map<String,String> mpprodparenttocaseprod = New Map<String,String>();
		Map<Id,List<Asset>> mpacctassets = New Map<Id,List<Asset>>();
		Map<Id,Entitlement> mpassettoentl = New Map<Id,Entitlement>();
		List<CaseProductTypes__c> lstcs = CaseProductTypes__c.getAll().values();
		List<Case> lstnoncontracted = New List<Case>();
		Boolean isnoncontracted = false;
		List<EC_Case_Product_Types__c> lstsetting = EC_Case_Product_Types__c.getAll().values();
		List<Contact> lstcontact = New List<Contact>();
		Set<Id> setcontactid = New Set<Id>();
		Map<Id,Id> mpcontoaccount = new Map<Id,Id>();
		List<Case> lstreturncase = New List<Case>();

		for(EC_Case_Product_Types__c cs :lstsetting)
		{
			mpecproducttypes.put(cs.Experience_Cloud_Case_Value__c, cs.Case_Product_Type__c);
		}

		for(CaseProductTypes__c cpt :lstcs)
		{  
			if(cpt.Name.Contains('Product Parent'))
			{ mpprodparenttocaseprod.put(cpt.Name,cpt.Product_Inventory__c); }
            //system.debug(cpt.Name +', ' +cpt.Product_Inventory__c);
		}

		for(Case c :lsttrigger)
		{	system.debug('case contact is ' +c.contactid);
			if(c.ContactId != null && c.origin == 'SONIFI Portal')
			{
				setcontactid.add(c.contactid);
			}
		}

		system.debug('setcontactid size is ' +setcontactid.size());

		if(setcontactid.size() > 0)
		{
			lstcontact = [Select Id, Name, Accountid from Contact where id in :setcontactid];
			for(Contact c :lstcontact)
			{
				mpcontoaccount.put(c.id,c.accountid);
			}
		}

		system.debug('mpcontoaccount size is ' +mpcontoaccount.size());
		if(mpcontoaccount.size() > 0)
		{
			for(Case c :lsttrigger)
			{	
				Id accid;
				if(mpcontoaccount.containskey(c.ContactId))
				{	
					accid = mpcontoaccount.get(c.contactid);
					mpprocesscase.put(accid,c);
                	system.debug('mpprocesscase = ' +accid +', '+c);
					mpcaseproducts.put(accid, c.Impacted_Product_Type__c); //impacted product type comes through from the EC selection
					//mpcaseproducts.put(c.accountid,c.case_product_type__c);
                	system.debug('mpcaseproducts = ' +accid +', ' +c.Impacted_Product_Type__c);
					setaccid.add(accid);
				}
			}
		}
		//get the product inventory with related entitlement from the account id's on the cases
		List<Asset> lsta = New List<Asset>([Select Id, AccountId, Name,(Select Id,Name, AccountId, AssetId, Asset.Name, Status,ServiceContractId from Entitlements
		                                    where status = 'Active')
		                                    from Asset where AccountId in :setaccid and (name like '%Product Parent') and
                                            status in ('Installed Activated', 'Billing', 'Pending De-Installation')]);

        system.debug('lstsa size is ' +lsta.size());
	   if(lsta.size() > 0)  //create a map with account id as key and list of assets as value
	   {
			for(Asset a :lsta)
			{
				if(mpacctassets.containskey(a.accountid))
				{
					mpacctassets.get(a.accountid).add(a);
				}
				else
				{
					List<Asset> templist = New List<Asset>();
					templist.add(a);
					mpacctassets.put(a.accountid,templist);
				}

				for(Entitlement e :a.entitlements)
				{
					mpassettoentl.put(a.id,e);
				}
			
			}

			for(Id key :mpacctassets.keyset())
			{
				Case thiscase = New Case();
				if(mpprocesscase.containskey(key))
				{  thiscase = mpprocesscase.get(key);}

				if(thiscase != null)
				{	
					String ecselected = thiscase.Impacted_Product_Type__c;
					String caseprod;
					if(ecselected != null)
					{ caseprod = mpecproducttypes.get(ecselected); 
						system.debug('caseprod is ' +caseprod);
					}
	
				
					system.debug('isnoncontracted = ' +isnoncontracted);

					List<Asset> lstaccasset = New List<Asset>();
					if(mpacctassets.size() > 0)
					{ lstaccasset = mpacctassets.get(key); }
					system.debug('lstaccasset size = ' +lstaccasset.size());
					
					for(Asset a :lstaccasset)
					{
						if(mpcaseproducts.containskey(a.AccountId) && isnoncontracted == false)
						{
						
							if(mpprodparenttocaseprod.size() > 0 && mpprodparenttocaseprod.containskey(a.Name))
							{
								String prodabbrev = mpprodparenttocaseprod.get(a.Name);
								system.debug('prodabbrev = ' +prodabbrev);
								if(mpassettoentl.size() > 0 && mpassettoentl.containskey(a.Id) && prodabbrev == caseprod)
								{
									Entitlement e = New Entitlement();
									e = mpassettoentl.get(a.id);
									
										thiscase.AssetId = e.AssetId;
										thiscase.EntitlementId = e.id;
										thiscase.Service_Contract_Name__c = e.ServiceContractId;
										thiscase.Case_Product_Type__c = caseprod;
										lstreturncase.add(thiscase);
									
								}

								if(mpassettoentl == null || !mpassettoentl.containskey(a.id))
								{
									thiscase.case_product_type__c = caseprod;
									thiscase.assetid = a.id;
									isnoncontracted = true;
									lstnoncontracted.add(thiscase);
								}
							}
					
						}
					}  //end if asset loop

					if(thiscase.assetid == null)  //if no matching asset was found for the selected type
					{	
						thiscase.Case_Product_Type__c = caseprod;
						isnoncontracted = true;
						lstnoncontracted.add(thiscase);
					}
				}

			}//end for mpacctassets.keyset()
	   }
	   else {
		
			// create a non-contracted case if there are no assets on the account that meet the criteria
			isnoncontracted = true;
	  }

	  if(isnoncontracted == true)  //if there is no entitlement or no active entitlement for the product, create noncontracted case
	  {
		 //get the non-contract entitlement and service contract id's from the custom setting
		 system.debug('inside isnoncontracted=true');
		 AppConfig__c appconfigcs = AppConfig__c.getInstance('Global');
		 String entid = appconfigcs.Not_Contracted_Entitlement__c;
		 String scid = appconfigcs.Base_Service_Contract__c;
		 
		 for(Id accid :mpprocesscase.keyset())
		 {
				if(!mpacctassets.containskey(accid))
				{

					Case nonconcase = mpprocesscase.get(accid);
					if(nonconcase.Impacted_Product_Type__c != null)
					{ nonconcase.Case_Product_Type__c = mpecproducttypes.get(nonconcase.Impacted_Product_Type__c);}
					lstnoncontracted.add(nonconcase);
				}
		 }

		 for(Case c  :lstnoncontracted)
		 {
			c.EntitlementId = entid;
			c.Service_Contract_Name__c = scid;
			lstreturncase.add(c);
		 }
	  }
	   

        system.debug('*********END PopulateExperienceCloudCase*********');

		return lstreturncase;

	}//end method
    
}