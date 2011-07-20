@isTest
private class Test_NewsletterContentController {
	
	static Newsletter__c n;
	static NewsletterContentController ext;
	static PageReference pref;
	
	static {
		n = new Newsletter__c(name='Monthly');
		insert n;
	}
	
	static testMethod void testContentGeneration(){
		
    pref = Page.NewsletterContent;
    pref.getParameters().put('id',n.id);
    Test.setCurrentPage(pref);
             
    ApexPages.StandardController con = new ApexPages.StandardController(n);
    ext = new NewsletterContentController(con);

    Test.startTest();
    
    System.assert(ext.content != null);
    
    Test.stopTest();
		
		
	}
	
	

}