/***************************************************************************
 Name : Logger
 Created By : Jeff Douglas (jeff@appirio.com)
 Created Date : July 21, 2011
 Description : Asynchrous class that insert log records the Log__c object.         
***************************************************************************/

public class Logger {
	
	public static String INFO;
	public static String DEBUG;
	public static String WARNING;
	public static String ERROR;
	public static String FATAL;
	
	@future
	public static void log(String priority, String className, String message) { 
    insert (new Log__c(priority__c=priority,class__c=className,message__c=message));
	}
	
	// test method
	public static testMethod void testLogger() {
		Test.startTest();
		Logger.log(Logger.INFO, 'TestClassName', 'My Test Message');
		Test.stopTest();
		System.assertEquals(1,[select count() from Log__c where class__c = 'TestClassName']);
	}

}