/*
    Copyright (c) 2017, Salesforce.org
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Salesforce.org
* @date 2017
* @group Customizable Rollups Operations Services
* @description Unit Test for the Allocation to General_Accounting_Until Rollups
*/
@isTest
private class CRLP_RollupGAU_TEST {

    private Enum TestType {
        TestLDV
    }

    /**
     * @description Create Rollup__mdt records to test rolling up from the Opp and Payment objects to the Account
     */
    private static void mockRollupCMTValues() {

        // Create a single Filter Group (no need for filter rules here)
        String filterGroupId1 = CMT_UnitTestData_TEST.getNewRecordId();
        String filterGroupId2 = CMT_UnitTestData_TEST.getNewRecordId();

        // Extremely simple Filter Rule for IsWon only
        String filterGroupsJSON = '[' +
                CMT_UnitTestData_TEST.createFilterGroupRecord(filterGroupId1, 'TestFilterGroup1-IsWon+Paid') + ',' +
                CMT_UnitTestData_TEST.createFilterGroupRecord(filterGroupId2, 'TestFilterGroup2-IsWon+WrittenOff') +
                ']';
        String filterRulesJSON = '[' +
                CMT_UnitTestData_TEST.createFilterRuleRecord(null, filterGroupId1, 'Group1.Rule1', 'Opportunity', 'IsWon', 'Equals', 'True') + ',' +
                CMT_UnitTestData_TEST.createFilterRuleRecord(null, filterGroupId1, 'Group1.Rule2', 'npe01__OppPayment__c', 'npe01__Paid__c', 'Equals', 'True') + ',' +
                CMT_UnitTestData_TEST.createFilterRuleRecord(null, filterGroupId2, 'Group2.Rule1', 'Opportunity', 'IsWon', 'Equals', 'True') + ',' +
                CMT_UnitTestData_TEST.createFilterRuleRecord(null, filterGroupId2, 'Group2.Rule2', 'npe01__OppPayment__c', 'npe01__Written_Off__c', 'Equals', 'True') +
                ']';

        // Deserialize the filter group and filter rule to use for the tests
        CMT_FilterRule_SEL.cachedFilterGroups = (List<Filter_Group__mdt>)JSON.deserialize(filterGroupsJSON, List<Filter_Group__mdt>.class);
        CMT_FilterRule_SEL.cachedFilterRules = (List<Filter_Rule__mdt>)JSON.deserialize(filterRulesJSON, List<Filter_Rule__mdt>.class);

        // Create a single Rollup that uses the above Filter Group
        // TODO Add many more rollup variations to this
        String rollupsJSON = '[' +
                CMT_UnitTestData_TEST.createRollupRecord('Household Total Allocations All Time', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.GAU,
                        'Total_Allocations__c', CRLP_Operation.RollupType.SUM, 'Amount__c',
                        CRLP_Operation.YearlyOperationType.ALL_TIME, 0) + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Average Allocations All Time', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.GAU,
                        'Average_Allocation__c', CRLP_Operation.RollupType.AVERAGE, 'Amount__c',
                        CRLP_Operation.YearlyOperationType.ALL_TIME, 0) + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Allocations 2 Years Ago', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.GAU,
                        'Total_Allocations_Two_Years_Ago__c', CRLP_Operation.RollupType.SUM, 'Amount__c',
                        CRLP_Operation.YearlyOperationType.YEARS_AGO, 2) + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Max Allocation All Time', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.GAU,
                        'Largest_Allocation__c', CRLP_Operation.RollupType.LARGEST, 'Amount__c',
                        CRLP_Operation.YearlyOperationType.ALL_TIME, 0) + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Years Donated', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.GAU,
                        'Description__c', CRLP_Operation.RollupType.YEARS_DONATED, '',
                        CRLP_Operation.YearlyOperationType.ALL_TIME, 0) + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Current Donation Streak', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.GAU,
                        'Total_Allocations_Last_N_Days__c', CRLP_Operation.RollupType.CURRENT_STREAK, '',
                        null, 0) +
                ']';

        // Deserialize the rollups to use for testing
        CRLP_Rollup_SEL.cachedRollups = (List<Rollup__mdt>) JSON.deserialize(rollupsJSON, List<Rollup__mdt>.class);
    }

    static testMethod void test_Rollups_BatchLDV() {
        testRollupsServices(TestType.TestLDV);
    }

    /**
     * @description Test some simple rollups from the Opportunity/Payment object to the Account
     */
    private static void testRollupsServices(TestType tt) {

        // create two GAU's
        General_Accounting_Unit__c defaultGau1 = new General_Accounting_Unit__c(Name='GAU #1');
        General_Accounting_Unit__c defaultGau2 = new General_Accounting_Unit__c(Name='GAU #2');
        insert new List<General_Accounting_Unit__c>{defaultGau1, defaultGau2};

        // Create a Campaign and assign the two GAU's as Allocations each at 50%.
        Campaign cam = new Campaign(Name='Foo', IsActive=true);
        insert cam;

        List<Allocation__c> allocs = new List<Allocation__c>();
        allocs.add(new Allocation__c(Campaign__c=cam.id, Percent__c = 50, General_Accounting_Unit__c = defaultGau1.id));
        allocs.add(new Allocation__c(Campaign__c=cam.id, Percent__c = 50, General_Accounting_Unit__c = defaultGau2.id));
        insert allocs;

        // Start by enabling Customizable Rollups (which disables all legacy rollup operations)
        UTIL_CustomSettingsFacade.getRollupSettingsForTests(new Customizable_Rollup_Settings__c (
                        Customizable_Rollups_Enabled__c = true,
                        Rollups_Limit_on_Attached_Opps_for_LDV__c = 150,
                        Rollups_Account_Batch_Size__c = 20,
                        Rollups_Allocation_Batch_Size__c = 400,
                        Rollups_LDV_Batch_Size__c = 100
                )
        );

        // Create the test data
        mockRollupCMTValues();

        // Disable all legacy rollup triggers
        UTIL_UnitTestData_TEST.disableRollupTriggers();
        // Disable all customizable rollup triggers
        UTIL_UnitTestData_TEST.disableCustomizableRollupTriggers();

        // Insert a dummy Contact and 100 Opportunity records
        Contact c = new Contact(LastName = 'UNITTEST', FirstName = 'TEST');
        insert c;
        c = [SELECT Id, FirstName, LastName, AccountId FROM Contact LIMIT 1];
        Id acctId = c.AccountId;

        String closedStage = UTIL_UnitTestData_TEST.getClosedWonStage();
        Id rtId = UTIL_RecordTypes.getRecordTypeIdForGiftsTests(Opportunity.SObjectType);

        List<Opportunity> opps = new List<Opportunity>();
        Date closeDate = Date.Today().addMonths(-100);
        Decimal totalDonations = 0, total2YearsAgo = 0;
        Decimal maxAmt = 1000;
        Decimal baseAmt = 100;
        Integer cnt = 100;
        String bestGiftYear;
        Set<String> donationYears = new Set<String>();
        Date lastCloseDate;
        for (Integer n=0; n<cnt; n++) {
            Decimal amt = (n==50 ? maxAmt : baseAmt);
            opps.add(new Opportunity (
                    Name = 'Test Opp ' + c.FirstName + ' ' + c.LastName,
                    Amount = amt,
                    CampaignId = cam.Id,
                    CloseDate = closeDate.addMonths(n),
                    StageName = closedStage,
                    Primary_Contact__c = c.Id,
                    RecordTypeId = rtId
            ));
            totalDonations += (amt/2);  // Using 2 allocations each getting 50%
            if (closeDate.addMonths(n).year() == Date.Today().addYears(-2).year()) {
                total2YearsAgo += (amt/2);
            }
            String donationYr = closeDate.addMonths(n).year().format().replace(',','');
            donationYears.add(donationYr);
            if (amt == maxAmt) {
                bestGiftYear = donationYr;
            }
            lastCloseDate = closeDate.addMonths(n);
        }

        // create one closed lost opportunity to ensure it's not included in our rollups
        opps.add(new Opportunity (
                Name = 'Test Opp ' + c.FirstName + ' ' + c.LastName,
                Amount = 500,
                CloseDate = Date.Today().addDays(1),
                StageName = UTIL_UnitTestData_TEST.getClosedLostStage(),
                Primary_Contact__c = c.Id,
                RecordTypeId = rtId
        ));
        insert opps;

        system.assertEquals(cnt * 2, [SELECT Count() FROM Allocation__c WHERE Opportunity__r.IsWon = true],
                'There should be 200 Allocation records on closed won opps');

        Id gauId = defaultGau1.Id;

        // Now test the rollups to the GAU from the Allocation using the LDV Batch Job
        // since this is the only rollup method that supports allocations
        Test.startTest();
        Integer batchSize = CRLP_Rollup_SVC.getLDVBatchSize(General_Accounting_Unit__c.SObjectType);
        database.executeBatch(new CRLP_Rollup_BATCH_LDV(new List<Id>{ defaultGau1.Id, defaultGau2.Id } ), batchSize);
        Test.stopTest();

        // Query the Account with all the target fields specified in the rollups
        String gauQuery = CRLP_Query_SEL.getResultsQuery(General_Accounting_Unit__c.SObjectType) + ' WHERE Id = :gauId LIMIT 1';
        General_Accounting_Unit__c gau = database.query(gauQuery);

        // Basic rollup asserts using existing NPSP rollup fields.
        System.assertEquals(totalDonations, gau.Total_Allocations__c);
        System.assertEquals((totalDonations / cnt), gau.Average_Allocation__c);
        System.assertEquals(total2YearsAgo, gau.Total_Allocations_Two_Years_Ago__c);
        System.assertEquals(maxAmt/2, gau.Largest_Allocation__c);

        System.assertEquals(donationYears.size(), gau.Total_Allocations_Last_N_Days__c, 'The current streak should be all the years');
        System.assertEquals(donationYears.size(), gau.Description__c.split(';').size(), 'The list of donated years should match');
    }
}