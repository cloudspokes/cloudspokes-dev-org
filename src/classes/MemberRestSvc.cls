/***************************************************************************
 Name : MemberRestSvc
 Created By : Jeff Douglas (jeff@appirio.com)
 Created Date : July 18, 2011
 Description : An Apex REST service to that supports the following
 operations:
 
  1. GET /members - Returns a collection of sObjects with support for:
     - Return fields: ?fields=Id,Name,Email__c (defaults to Id,Name)
     - Resultset limit: ?limit=10
     - Order by: ?orderby=Name
     - Search (LIKE) by username: ?search=some-member
   
  2. GET /members/some-member - Returns a collection containing a
   single sObject. Support for:
     - Return fields: ?fields=Id,Name,Email__c (defaults to Id,Name)
     
  3. POST /members - Creates a new member and associated Salesforce.com
    user. Required parameters include: Username__c, Email__c, 
    Last_Name__c and First_name__c. Optional parameters include 
    Third_Party_Account__c, Third_Party_Username__c, password. Password
    must be included if Third_Party_Account__c and Third_Party_Username__c
    are *not* included in parameters.
    
  4. PUT /members/some-member - Updates the some-member Member__c
    record with fields included in the request parameters. Not all fields
    are updatable and an exception will be returned instead of the record
    id.    
    
 Best practice is for field name parameters to be passed as all 
 lowercase. For example, use "first_name__c" instead of "First_Name__c". 
          
***************************************************************************/

@RestResource(urlMapping='/v.9/members/*') 
global with sharing class MemberRestSvc { 

  /**
  * @author Jeff Douglas
  * @date 7/18/2011
  * @description GET method that supports /members and /members/some-member.
    Delegates responsibility to individual private methods depending on
    whether a username is specified.
  * @return List<Member__c> collection of Member__c sObject(s)
  */
  @HttpGet
  global static List<Member__c> doGet(RestRequest req, RestResponse res) {
  	
  	// see if a username was part of the uri
  	String username = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
 
  	if (username != 'members') {
  		return getMember(username, req);
  	} else {	
  		return getMembers(req);
  	} 

  }
  
  /**
  * @author Jeff Douglas
  * @date 7/18/2011
  * @description POST method that supports /members to create a new member. 
    Delegates responsibility to the createMember() method.
  * @return String the record's ID or error message
  */
  @HttpPost
  global static String doPost(RestRequest req, RestResponse res) {
    
    // see if a username was part of the uri
    String username = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
 
    if (username == 'members') {
      return createMember(req);
    } else {  
      return 'Invalid operation';
    }
    
  }
  
  /**
  * @author Jeff Douglas
  * @date 7/18/2011
  * @description PUT method that supports /members/some-member to 
    update a member. Delegates responsibility to the updateMember() method.
  * @return String the record's ID or error message
  */
  @HttpPut
  global static String doPut(RestRequest req, RestResponse res) {
    
    // see if a username was part of the uri
    String username = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
 
    if (username != 'members') {
      return updateMember(username, req);
    } else {
    	return 'Invalid operation';
    }
    
  }
  
	/**
	* @author Jeff Douglas
	* @date 7/18/2011
	* @description Queries for the specified member by username and returns
	  the record with the fields specified.
	* @param username Member's username__c 
	* @param req RestRequest object containing parameters
	* @return List<Member__c> collection of a single Member__c sObject. If no
	  records is found it will simply return a null value.
	*/
  private static List<Member__c> getMember(String username, RestRequest req) {
  	
    // default fields to return 
    String qryFields = 'id, name';
    // set the fields to return
    if (req.params.containsKey('fields')) qryFields = req.params.get('fields');
  	
    return Database.query('select ' + qryFields + ' from member__c where username__c = \'' + username +'\'');
  	
  }
  
  /**
  * @author Jeff Douglas
  * @date 7/18/2011
  * @description Queries for members and returns the records 
    with the fields specified. Support for limit and orderby.
    Also performs a search using LIKE keyword.
  * @param req RestRequest object containing parameters
  * @return List<Member__c> collection of Member__c sObjects
  */
  private static List<Member__c> getMembers(RestRequest req) { 
  	
  	// TODO - implement pagination /members?limit25&offset=50
  	// TODO - implement variations /members?color=red-state=running
  	
    // default fields to return 
    String qryFields = 'id, name';
    // default query limit   
    String qryLimit = 'limit 100';   
    // default order by
    String qryOrderby = '';      
    // default where clause
    String qryWhere = '';  
      
    // set the fields to return
    if (req.params.containsKey('fields')) qryFields = req.params.get('fields');
    // set the limit for records to return
    if (req.params.containsKey('limit')) qryLimit = 'limit ' + req.params.get('limit'); 
    // set the order by
    if (req.params.containsKey('orderby')) qryOrderby = 'order by ' + req.params.get('orderby');
    // set the where clause to search by username
    if (req.params.containsKey('search')) qryWhere = 'where username__c LIKE \'' + req.params.get('search') +'%\'';
      
    return Database.query('select ' + qryFields + ' from member__c ' + qryWhere + ' ' + qryOrderby + ' ' + qryLimit);
  	
  }

  /**
  * @author Jeff Douglas
  * @date 7/18/2011
  * @description Updates a member's record with parameters passed
  * @param username Member's username__c 
  * @param req RestRequest object containing parameters to be updated
  * @return String the record's ID or error message
  */
  private static String updateMember(String username, RestRequest req) {  	
  	
    // get a map of all field in the member__c custom object
    Map<String, Schema.SObjectField> sObjectFieldsMap = Schema.SObjectType.Member__c.fields.getMap();
    // don't let them update the following fields -- use all lowercase for comparison
    Set<String> noUpdateFields = new Set<String>{'username__c'};
  	
  	Member__c m;
  	
  	try {
  		
  		// fetch the member by username if it exists
      m = [select id from Member__c where Username__c = :username];
  	
		  // populate the object's fields
		  for (String key : req.params.keySet()) {
        // only add params if they are valid field on the object and not on the no-update list
        if (sObjectFieldsMap.containsKey(key) && !noUpdateFields.contains(key.toLowerCase()))
		      m.put(key,req.params.get(key)); 
		  }
		  
		  update m;
		  
    } catch (QueryException e) {
      return 'Member not found for: ' + username;		  
    } catch (DMLException e1) {
      return e1.getDmlMessage(0);   
    } catch (Exception e2) {
      return e2.getMessage();
  	}   

  	return m.id;
  }
  
  /**
  * @author Jeff Douglas
  * @date 7/18/2011
  * @description Creates a new member and associated user
  * @param req RestRequest object containing parameters to be used
    for both the member and user records.
  * @return String the record's ID or error message
  */
  private static String createMember(RestRequest req) {
  	
  	// create a new member and populate with request params
 	  Member__c m = new Member__c();
 	  // get a map of all field in the member__c custom object
 	  Map<String, Schema.SObjectField> sObjectFieldsMap = Schema.SObjectType.Member__c.fields.getMap();
 	  // set a save point so we can rollback if an error
 	  Savepoint sp = Database.setSavepoint();
 	  
 	  try {
 	  	
 	  	// populate a new user object
	    User u = new User(alias=req.params.get('username__c').substring(0,7), email=req.params.get('email__c'),
	        emailencodingkey='ISO-8859-1', lastname=req.params.get('last_name__c'), languagelocalekey='en_US',
	        firstname=req.params.get('first_name__c'), localesidkey='en_US', 
	        profileid=[select id from profile where name = 'Member'].Id, 
	        timezonesidkey='America/Los_Angeles', username=req.params.get('username__c')+'@m.cloudspokes.com');
	        
      // add the third party info if not null
      if (req.params.containsKey('third_party_account__c'))
        u.Third_Party_Account__c = req.params.get('third_party_account__c');
      if (req.params.containsKey('Third_Party_Username__c'))
        u.Third_Party_Username__c = req.params.get('third_party_username__c');
      
      // insert the user
 	  	insert u;
 	  	
 	  	// populate the new member object's fields
	    for (String key : req.params.keySet()) {
	    	// only add params if they are valid field on the object
	    	if (sObjectFieldsMap.containsKey(key))
	    	  m.put(key,req.params.get(key)); 
	    }
 	  	
 	  	// link the member to the newly created user
 	  	m.SFDC_User__c =  u.id;
 	  	
 	  	// insert the member
      insert m;
      
      // set the user's password - no pass means 3rd party
      if (req.params.containsKey('password')) {
        System.setPassword(u.id, req.params.get('password'));
      } else {
      	System.setPassword(u.id, '!cloudspokes11');
      }
      
 	  } catch (DMLException e1) {
 	  	Database.rollback(sp);
 	  	return e1.getDmlMessage(0); 	
    } catch (Exception e2) {
      Database.rollback(sp);
      return e2.getMessage();   
 	  }
    
    return m.id;
  }


}