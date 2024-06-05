global class CaseTriggerLogicCallTekCases {
    /*

jjackson 4/2024:  New trigger logic class for support cases that are created via web service from the
CallTek call center. These cases come in via web service and contain very little information (basically the
site id, the case origin so we know it's a CallTek case, and the case product type.)
Joan Jackson 5/1/2024: CallTek cases project
Sonifi Solutions

*/

    //jjackson 8/10/22 -- run after insert so we have the case id
	global static void populateCallTekCase(Map<Id,Case> trignewmap)
	{	
		system.debug('*********BEGIN PopulateCallTekCase************');
        
        List<Case> lstupdcase = New List<Case>();
		Set<Case> setcase = New Set<Case>();
		Map<Id,String> mpcasetosite = New Map<Id,String>();
		Set<String> setsites = New Set<String>();
		List<Asset> lstassetinfo = New List<Asset>();
		Map<String,List<Asset>> mpsitetoasset = New Map<String,List<Asset>>();
		Map<Id,List<Entitlement>> mpentitlement = New Map<Id,List<Entitlement>>();
		Map<Id,Case> mpcasenotes = New Map<Id,Case>();
		Id rectypeid = Utilities.RecordTypeNametoId('Case', 'Support Case');
		Id rectypeclosed = Utilities.RecordTypeNametoId('Case', 'Support Case Closed');
		Map<String,Id> mpsitetoid = New Map<String,Id>();
		Id ownershipid;
		Set<String> setprodparents = New Set<String>();

		if(test.isRunningTest())
		{ ownershipid = UserInfo.getUserId(); }
		else{
		//get the queue id for these cases to set the owner field
			Group ownership = [Select Id, Name, Type from Group where Name = 'Calltek TAC Escalation' AND type = 'Queue' LIMIT 1];
			ownershipid = ownership.id;
			system.debug('ownershipid for this case is ' +ownershipid);
		}

		
		for(Case c :trignewmap.values())
		{	
			if(c.case_product_type__c == 'Broadband' || c.case_product_type__c == 'STAYCAST')
			{
				mpcasetosite.put(c.id,c.Site_ID__c);
				setsites.add(c.Site_ID__c);

				system.debug('setsites size is ' +setsites.size());

				if(c.Notes__c != null)
				{ mpcasenotes.put(c.id,c); }
			}
		}

		lstassetinfo = [Select id, accountid, account.Site_ID__c, name, status, (select name, id, assetid, asset.name, ServiceContractId from
		                Entitlements) from Asset where account.site_id__c in :setsites AND (status = 'Pending Installation Activate' OR
						status = 'Installed Activated' OR status = 'Billing') AND (name = 'Broadband Product Parent' OR
						name = 'STAYCAST Product Parent')];

		system.debug('lstassetinfo size is ' +lstassetinfo.size());

		if(lstassetinfo.size() > 0)
		{

			for(Asset a :lstassetinfo)
			{	

				setprodparents.add(a.name);

				mpsitetoid.put(a.account.site_id__c,a.accountid);
				//system.debug('mpsitetoid size is ' +mpsitetoid);

				if(mpsitetoasset.containskey(a.account.site_id__c))
				{ mpsitetoasset.get(a.account.Site_ID__c).add(a); }
				else
				{
					List<Asset> lsttemp = New List<Asset>();
					lsttemp.add(a);
					mpsitetoasset.put(a.account.Site_ID__c, lsttemp);
				}

				Integer entsize = a.entitlements.size();
				system.debug('entsize  is ' +entsize);
				
				//for each entitlement in the subquery, add to the map with key of asset id and list of
				//subquery entitlements per asset in the list
				if(entsize > 0)
				{	
					for(Entitlement e :a.entitlements)
					{
						if(mpentitlement.containskey(a.id))
						{
							mpentitlement.get(a.id).add(e);
						}
						else
						{
							List<Entitlement> lsttemp = New List<Entitlement>();
							lsttemp.add(e);
							mpentitlement.put(a.id,lsttemp);
						}
					}
				}
			}//end if for lstasset
				
			for(Id key :mpcasetosite.keyset())
			{
				String siteid = mpcasetosite.get(key);
				Id accid;
				
				if(mpsitetoid.containskey(siteid))
				{
					accid = mpsitetoid.get(siteid);
				}

				if(mpsitetoasset.containskey(siteid))
				{
					List<Asset> lstgetassets = New List<Asset>();

					lstgetassets = mpsitetoasset.get(siteid);

					if(trignewmap.containskey(key))
					{
						String prodtype = trignewmap.get(key).case_product_type__c;
						String prodparent = prodtype +' Product Parent';
						system.debug('prodparent is ' +prodparent);
					
						Boolean notcontracted = false;

						if(lstgetassets.size() > 0 && setprodparents.contains(prodparent))
						{
							for(Asset a :lstgetassets)
							{
								if(a.name == prodparent)
								{
									Case updcase = New Case();
									updcase.recordtypeid = rectypeid;
									updcase.id = key;
									updcase.assetid = a.id;
									updcase.accountid = accid;
									updcase.ownerid = ownershipid;

									if(updcase.status == 'Closed')
									{ updcase.ClosedDate = system.now();
									  updcase.recordtypeid = rectypeclosed;
									}

									if(mpentitlement.containskey(a.id))
									{ 
										String entid;
										String scid;

										List<Entitlement> lstgetentitlements = New List<Entitlement>();
										lstgetentitlements = mpentitlement.get(a.id);
										for(Entitlement ent :lstgetentitlements)
										{
											if(ent.asset.name == prodparent)
											{
												entid = ent.id;
												scid = ent.ServiceContractId;
											}
										}

										updcase.EntitlementId = entid;
										updcase.Service_Contract_Name__c = scid;
										setcase.add(updcase);
									
									}
									else  //if there is no entitlement that matches this case product type, create a non-contracted case
									{	
										Case newcase = New Case();
										newcase = CreateNonContractedCase(key, rectypeid, accid, ownershipid);
										setcase.add(newcase);
									}

								}
							}
						}
						else //if there is no product inventory that matches the case product type, create a non-contracted case
						{
							Case newcase = New Case();
							newcase = CreateNonContractedCase(key, rectypeid, accid, ownershipid);
							setcase.add(newcase);
						}
					}	//mpsitetoasset key loop
				}//end for mpcasetosite
			}//end if mpcasetosite > 0
		}
		else //if no assets are found at all 
		{	

			system.debug('CallTek Case Creation: No Product Inventory for Broadband or STAYCAST');
				/*List<Account> lstacc = New List<Account>();
				Map<String,Id> mpsitetoacctid = New Map<String,Id>();
				lstacc = [Select Id, site_id__c from Account where site_id__c in :setsites ];
				for(Account a :lstacc)
				{ mpsitetoacctid.put(a.site_id__c,a.id); }
				for(Id key :mpcasetosite.keyset())
				{	
					String siteid = mpcasetosite.get(key);
					Id acctid;

					if(mpsitetoacctid.containskey(siteid))
					{
						acctid = mpsitetoacctid.get(siteid);
						Case nonconcase = CreateNonContractedCase(key, rectypeid, acctid, ownershipid);
						setcase.add(nonconcase);
					}

					
				}*/
		}//end else
		
			if(setcase.size() > 0)
			{ lstupdcase.addAll(setcase); }

			//add try/catch for updating the cases
			system.debug('lstcase size ' +lstupdcase.size());

			if(lstupdcase.size() > 0)
			{
				try{ update lstupdcase; }
				catch(Exception e)
				{
					system.debug('error updating calltek cases ' +e.getMessage());
					for(Case c :lstupdcase)
					{
						system.debug('case id is ' +c.id);
					}
				}
			}

		//add code or method that creates the case task from notes on the case
		if(mpcasenotes.size() > 0)
		{
			CaseTriggerLogicCallTekCases.CreateCaseTasks(mpcasenotes);
		}
	}//end populateCallTekCase

	public static Case CreateNonContractedCase(Id caseid, Id rectype, Id acctid, Id caseowner)
	{	
		String nonentid = AppConfig__c.getInstance('Global').Base_SLA__c;
		String nonsc = AppConfig__c.getInstance('Global').Base_Service_Contract__c;

		//use the id's in the dev box for testing in the dev box
		//String nonentid = '550WC000001fLeCYAU';
		//String nonsc = '810WC000000MpTTYA0';

		Case newcase = New Case();
		newcase.accountid = acctid;
		newcase.recordtypeid = rectype;
		newcase.id = caseid;
		newcase.EntitlementId = nonentid;
		newcase.Service_Contract_Name__c = nonsc;
		newcase.ownerid = caseowner;


		return newcase;

	}

	public static void CreateCaseTasks(Map<Id,case> mpnotes)
	{
		//TODO Get more information about what should be populated into the Task
		system.debug('**********BEGIN CreateCaseTasks*********');

		List<Task> lstinsert = New List<Task>();
		if(Schema.sObjectType.Case.Fields.Notes__c.isAccessible())
		{
			Id suppcasetype = Utilities.RecordTypeNameToId('Task', 'Support Case Task');
			
			for(Id key :mpnotes.keySet())
			{

				Case newcase = New Case();
				newcase = mpnotes.get(key);

				Task t = New Task();
				t.WhatId = key;
				t.description = newcase.notes__c;
				t.recordtypeid = suppcasetype;
				t.Subject = newcase.Subject +' - ' +system.Now();
				t.Status = 'Completed';
				t.Case_Product_Type__c = newcase.Case_Product_Type__c;
				t.Issue_Type__c = newcase.Issue_Type__c;
				t.Issue_Sub_Type__c = newcase.Issue_Sub_Type__c;
				t.Case_Status__c = newcase.status;
				t.Task_Customer_Name__c = newcase.Customer_Name__c;
				t.Task_Origin__c = 'CallTek';
				lstinsert.add(t);

			}
		}

		if(lstinsert.size() > 0)
		{ 
			try{insert lstinsert; }
			catch(Exception e)
			{
				system.debug('ERROR creating calltek case task: ' +e.getMessage());
			}
		}

		system.debug('*********END CreateCaseTasks**********');
	}
}









		

		
//////////////////////////////////////////////////////////////////////////old code below this
/*		system.debug('mpcontoaccount size is ' +mpcontoaccount.size());
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

	}//end method */
    
//}
