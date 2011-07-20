// this class is a temp hack and will not be used.

public with sharing class NewsletterContentController { 

  public Newsletter__c n {get;set;}
  public String content {get;set;}

  public NewsletterContentController(ApexPages.StandardController controller) {
    
    this.n = [select id, name from Newsletter__c where id = :ApexPages.currentPage().getParameters().get('id')];

    List<Challenge__c> open = [select id, name, end_date__c, sql_id__c, Blog_URL__c, teaser__c, Days_till_Close__c   
     from challenge__c where status__c = 'Created' and Days_till_Close__c > 0 and Name != 'Create an Idea for a CloudSpokes Challenge!' order by end_date__c];
    
    List<Challenge__c> closed = [select id, name, end_date__c, sql_id__c, Blog_URL__c, teaser__c, Days_till_Close__c 
      from challenge__c where status__c IN ('Winner Selected') and Name != 'Create an Idea for a CloudSpokes Challenge!' order by end_date__c DESC limit 7];

    content = '';
    generateContent(open);
    content += '<-- ========= START CLOSED CONTENT ========= -->';
    generateContent(closed);
    
  } 
  
  private void generateContent(List<Challenge__c> challenges) {
    
    for (Challenge__c c : challenges) {
      
      List<Challenge_Category__c > categories = [Select Category__r.name, Category__r.Color__c From Challenge_Category__c where challenge__c = :c.id];
      
      content += '<p><a href="http://www.cloudspokes.com/challenge_detail.html?contestID='+c.sql_id__c+'">' + c.name + '</a><br/><span style="font-size:12px;">' + c.teaser__c + '<br/>';
      
      Integer ct = 0;
      for (Challenge_Category__c cat : categories) {
        content += '<span style="color:'+cat.Category__r.Color__c+';">' + cat.Category__r.Name + '</span>';
        if (categories.size() > ct+1) {
          content += ', ';
          ct = ct + 1;
        }
        
      }
    
      if (c.Days_till_Close__c != 0) {
        content += '<br/>Top Prize: $0<br/>Ends: ' + c.end_date__c.format();
      } else {
          content += '<br/>Total Prizes: $';
          if (c.Blog_URL__c != null)
            content += '<br/><a href="'+c.Blog_URL__c+'">View Winning Demo</a>';
      }   
      
      content += '</span></p>';  
      
    }
  
  }

}