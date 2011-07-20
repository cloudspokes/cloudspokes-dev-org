global class qwikScore 
{
  //set up some variables
    public Id surveyId {get; set;}
    public Id participantId {get; set;}
    public Id userId {get;set; }
    public Id scoreCardId {get;set; }
    public String saveResult {get;set; }
    public list<QwikScore_Question_Answer__c> answerTemplates{get;set;}
    public boolean surveyGraded{get;set;}
    public boolean surveyActive{get;set;} 
    public string linkURL{get;set;}  
        
    //method for creating or finding a scorecard for a user for a given survey 
    public QwikScore_Scorecard__c createScoreCard(Id surveyId, Id participantId)
    {       
            QwikScore_Scorecard__c scoreCard;
            
            //try to find any existing scorecard for this survey for this user
            list<QwikScore_Scorecard__c> scoreCards = [select id 
                                                              from QwikScore_Scorecard__c 
                                                              where QwikScore_Survey__c = :surveyId and
                                                              Challenge_Participant__c = :participantId
                                                              Limit 1];
            //if there are no scorecards, create one and insert it
            if(scoreCards.isEmpty())
            {                               
                    scoreCard = new QwikScore_Scorecard__c();                                                
                    scoreCard.QwikScore_Survey__c = surveyId;
                    scoreCard.Challenge_Participant__c = participantId;      
                    insert scoreCard;
            }
            else
            {
                    scoreCard = scoreCards[0];
            } 
            
            //attempt to create any required answer templates (it won't make duplicates, so you can call it whenever)
            createAnswerTemplates(scoreCard.id, surveyId);
            
            //set our global scorecard id
            scoreCardId = scoreCard.id;        
            return scoreCard;
    }
        
    public list<QwikScore_Question_Answer__c> createAnswerTemplates(Id scoreCardId, Id surveyId)
    {
            //some variables needed for creating answer templates
            list<QwikScore_Question_Answer__c> answers = new list<QwikScore_Question_Answer__c>();
            
            //find all the questions that are in this survey
            list<QwikScore_Question__c> questions = [select id from QwikScore_Question__c where QwikScore_Question_Group__r.QwikScore_Survey__c = :surveyId];
            
            //loop over the questions
            for(QwikScore_Question__c q : questions)
            {
              //create an answer for each question
                QwikScore_Question_Answer__c thisAnswer = new QwikScore_Question_Answer__c();
                thisAnswer.Question__c = q.id;
                thisAnswer.QwikScore_Scorecard__c = scoreCardId;
                thisAnswer.Answer_Unique_Id__c = 'SC:'+scoreCardId+'-QID:'+q.id;
                answers.add(thisAnswer);
            }
            
            //attempt to inser the answers. Duplicates arn't allowed via a validation rule, so no worries about dupes
            database.insert(answers,false);
            
            return answers;
    }
        
    WebService static string gradeScoreCard(Id scoreCardId, Id surveyId)
    {
        string returnMessage = 'Scorecard Graded';
        
      try
        { 
          //To grade a score card, we need to find all answers associated with it, take their weighted scores and sum them.
          //then multiple that total by the group weight.
          decimal totalWeightedScore = 0.0;
          decimal maxScore = 0.0;
          
          if(maxScore == null)
          {
            maxScore = 0;
          }
          map<Id,decimal> groupWeights = new map<Id,decimal>();
          
          //we need to find the weight of each group. So query all the groups in this survey
          //then loop over them and add them to a map (groupID, groupWeight)
          list<QwikScore_Question_Group__c> groupWeightsQuery = [select Group_Weight__c, Id from QwikScore_Question_Group__c where QwikScore_Survey__c = :surveyId];
          for(QwikScore_Question_Group__c gW : groupWeightsQuery)
          {
              groupWeights.put(gw.id, gw.Group_Weight__c);
          }
          
          //ok now run an aggregate query that sums all the weighted question answers, but breaks them
          //down by the group so we can multile each total by it's group weight.    
          AggregateResult[] answers = [ select max(Question__r.Maximum_Value__c)maxScore, SUM(Weighted_Score__c)totalScore, Question__r.QwikScore_Question_Group__c
                                        from QwikScore_Question_Answer__c
                                        where IsAnswered__c = 1 and
                                        Question__r.Question_Type__c = 'Numeric' and
                                        QwikScore_Scorecard__c = :scoreCardId
                                        Group by ROLLUP(Question__r.QwikScore_Question_Group__c)];
          
          
          //loop over the groups. There is 1 row for each group (+1 for a grand total row that we ignore)                          
          for(AggregateResult ar: answers)
          {
              //An aggreate query contains a summary row at the end with the totals. Since we don't want to include
              //that in our math, add this if statment to exclude it, since it doesn't have a question group.
              if(ar.get('QwikScore_Question_Group__c') != null)
              {
   
                string questionGroup = (string) ar.get('QwikScore_Question_Group__c');
   
              decimal thisGroupWeight = 0.0;
              //if ithas no weight (it's basically a useless group) then dont divide by 0. Just set the weight to 0
              if(groupWeights.get(questionGroup) > 0)
              {
                    thisGroupWeight = groupWeights.get(questionGroup) / 100;
              }
              
                  decimal thisWeightedScore = (decimal)ar.get('totalScore');
                  decimal thisWeightedTotal = (thisWeightedScore * thisGroupWeight);
                  decimal thisMaxScore = (Decimal) ar.get('maxScore');
                  
                  totalWeightedScore += thisWeightedTotal;
                  //We also want to record the maximum score. This is useful for scoring if the maximum score for a survey
                  //is set beyond 4. The requirments of the project only wanted a max score of 4, but it is possible thanks to this
                  //and other configurable paramaters to have a higher max.
                  if(thisMaxScore > maxScore)
                  {
                      maxScore = thisMaxScore;
                  } 
              }                                                              
          }
          totalWeightedScore = (totalWeightedScore / maxScore)*100;
                  
          returnMessage += 'Final score: '+totalWeightedScore;
          
          //update the existing scorecard object with the new total weight and set the
          //scored checkmark to true so the user cannot modify their answers any more.
          QwikScore_Scorecard__c thisScoreCard = new QwikScore_Scorecard__c(Id=scoreCardId);
          thisScoreCard.Final_Score__c =  totalWeightedScore;
          thisScoreCard.Scored__c = true;
          update thisScoreCard;
        }
        catch(Exception e)
        {
          returnMessage = 'Error: '+e.getMessage();
        }    
        return returnMessage;
    }
 
  //simple method for saveing and grading a scorecard. To be called from the qwikscore tool page
    public PageReference finishAndSave()
    {
            saveRecords();
            gradeScoreCard(scoreCardId, surveyId);
            
            return page.qwikScoreComplete;
    }
    
    //method for saving. called from qwikscore tool page    
    public void saveRecords()
    {
        try
        {
            saveResult = '';
            //don't bother saving if there is no data to save
            if(answerTemplates != null)
            {
              //save the list of data. 
                database.update(answerTemplates,false);               
            }
        }
        catch(Exception e)
        {
            saveResult = 'Error Saving Data ' +e.getMessage();
        }
    }
           
    public void getQuestionList()
    {
        surveyId = Apexpages.currentPage().getParameters().get('surveyId');
        participantId = Apexpages.currentPage().getParameters().get('participantId');
        QwikScore_Scorecard__c thisScorecard;
            
        if(surveyId != null)
        {
            //First we should see if this user already has a scorecard for this survey. Is so, lets pull their existing answers.
            //if not, lets create them a scorecard and blank answers.       
                
            thisScorecard = createScoreCard(surveyId, participantId);      

            //now find all their answers so we can display them to be edited            
            answerTemplates = [select id,
                                      Answer_Text__c,
                                      QwikScore_Scorecard__r.Scored__c,
                                      Question__r.Question_Text__c,
                                      Question__r.Question_Type__c,
                                      Question__r.Question_Weight__c,
                                      Question__r.Maximum_Value__c,
                                      Question__r.Minimum_Value__c,
                                      Question__r.QwikScore_Question_Group__r.name,
                                      Question__r.QwikScore_Question_Group__r.QwikScore_Survey__r.Active__c
                                      from QwikScore_Question_Answer__c
                                      where Question__r.QwikScore_Question_Group__r.QwikScore_Survey__c = :surveyId
                                      order by Question__r.QwikScore_Question_Group__r.Sequence_Number__c, Question__r.Sequence_Number__c];
            
            //these two variables are set to prevent a user from modifying an already scored card
            //or a card for a survey that is no longer active.                                      
            surveyGraded = answerTemplates[0].QwikScore_Scorecard__r.Scored__c;
            surveyActive = answerTemplates[0].Question__r.QwikScore_Question_Group__r.QwikScore_Survey__r.Active__c;
        }                                                                                         
    }
    
    public void getResultLink()
    {
      list<Report> surveyResultReport = [select id from report where name = 'Survey Score Report'];
      list<QwikScore_Scorecard__c> scoreCard = [select name from QwikScore_Scorecard__c where id = :scoreCardId];
      
      //the report parameter only wants 15 chars instead of 18, so trim it down.
      string survey = String.valueOf(surveyId).substring(0,15);
      linkURL = URL.getSalesforceBaseURL().toExternalForm()+'/'+surveyResultReport[0].id+'?pv0='+survey+'&pv1='+scoreCard[0].name;
      
    }
    
    @isTest 
    public static void unitTests()
    {
      //my apologies for a lackluster testing class. I ran out of time :(
        QwikScore__c thisSurvey = new QwikScore__c();
        thisSurvey.name = 'Test Survey';
        thisSurvey.Active__c = true;
        thisSurvey.Survey_Description__c = 'a test survey';
        
        insert thisSurvey;
        
        QwikScore_Question_Group__c thisGroup = new QwikScore_Question_Group__c();
        thisGroup.name = 'Group 1';
        thisGroup.Group_Weight__c = 100;
        thisGroup.QwikScore_Survey__c = thisSurvey.id;
        thisGroup.Sequence_Number__c = 1;
        
        insert thisGroup;
        
        QwikScore_Question__c thisQuestion = new QwikScore_Question__c();
        thisQuestion.Question_Text__c = 'test question1';
        thisQuestion.Question_Type__c = 'Numeric';
        thisQuestion.Question_Weight__c = 100;
        thisQuestion.QwikScore_Question_Group__c = thisGroup.id;
        
        insert thisQuestion;
        
        PageReference indexPage = Page.qwikscore;
        system.test.setCurrentPageReference(indexPage);
        qwikScore Ctlr = new qwikScore();
        indexPage.getParameters().put('surveyId',thisSurvey.id);
                                  
        Ctlr.getQuestionList();   
        
        Ctlr.saveRecords();
        
        Ctlr.finishAndSave();
        
        Ctlr.getResultLink();
        
    }    

}