@isTest(SeeAllData=true)
private class TeamDashboardControllerTest {

    @isTest
    static void testGetTeamAttendancePercentage() {
        Test.startTest();
        Decimal pct = TeamDashboardController.getTeamAttendancePercentage();
        Test.stopTest();

        System.assertNotEquals(null, pct, 'Team attendance percentage should not be null');
    }

    @isTest
    static void testGetPendingLeaveRequests() {
        Test.startTest();
        List<TeamDashboardController.LeaveRequestWrapper> requests = TeamDashboardController.getPendingLeaveRequests();
        Test.stopTest();

        System.assertNotEquals(null, requests, 'Pending leave requests list should not be null');
    }

    @isTest
    static void testGetEmployeesBelowThreshold() {
        Test.startTest();
        List<TeamDashboardController.LowAttendanceWrapper> lowAttList = TeamDashboardController.getEmployeesBelowThreshold();
        Test.stopTest();

        System.assertNotEquals(null, lowAttList, 'Low attendance list should not be null');
    }

    @isTest
    static void testGetUpcomingInterviews() {
        Test.startTest();
        List<TeamDashboardController.UpcomingInterviewWrapper> interviews = TeamDashboardController.getUpcomingInterviews();
        Test.stopTest();

        System.assertNotEquals(null, interviews, 'Upcoming interviews list should not be null');
    }
}
