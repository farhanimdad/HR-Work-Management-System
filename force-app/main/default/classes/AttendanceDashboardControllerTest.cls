@isTest
private class AttendanceDashboardControllerTest {

    @isTest
    static void testNoAttendanceCase() {
        Employee__c emp = new Employee__c(
            Name = 'Test Employee No Attendance'
        );
        insert emp;

        Date today = Date.today();

        Test.startTest();
        AttendanceDashboardController.AttendanceStatsWrapper stats = 
            AttendanceDashboardController.getMonthlyStats(emp.Id, today.month(), today.year());
        Test.stopTest();

        System.assertNotEquals(null, stats, 'Stats wrapper should not be null');
        System.assertEquals(0, stats.totalDays, 'Total days should be 0');
        System.assertEquals(0, stats.presentCount, 'Present count should be 0');
        System.assertEquals(0, stats.absentCount, 'Absent count should be 0');
        System.assertEquals(0, stats.leaveCount, 'Leave count should be 0');
        System.assertEquals(0, stats.lateCount, 'Late count should be 0');
        System.assertEquals(0.0, stats.attendancePercentage, 'Attendance percentage should be 0.0');
    }

    @isTest
    static void testBulkAttendanceCase() {
        Employee__c emp = new Employee__c(Name = 'Primary Employee');
        Employee__c empOther = new Employee__c(Name = 'Secondary Employee');
        insert new List<Employee__c>{ emp, empOther };

        Date baseDate = Date.today();
        Integer targetMonth = baseDate.month();
        Integer targetYear = baseDate.year();

        List<Attendance__c> attList = new List<Attendance__c>();

        // 1. Target Employee: 28 distinct days in the target month (1 per day)
        for (Integer day = 1; day <= 28; day++) {
            String status;
            if (Math.mod(day, 2) == 0) {
                status = 'Present'; // 14 Present
            } else if (Math.mod(day, 4) == 1) {
                status = 'WFH'; // 7 WFH (total present/WFH = 21)
            } else if (Math.mod(day, 8) == 3) {
                status = 'Absent'; // 4 Absent
            } else {
                status = 'Leave'; // 3 Leave
            }

            DateTime checkInTime = (Math.mod(day, 3) == 0) ? 
                DateTime.newInstance(targetYear, targetMonth, day, 10, 30, 0) : 
                DateTime.newInstance(targetYear, targetMonth, day, 9, 0, 0);

            attList.add(new Attendance__c(
                Employee__c = emp.Id,
                Attendence_Date__c = Date.newInstance(targetYear, targetMonth, day),
                Check_In__c = checkInTime,
                Status__c = status
            ));
        }

        // 2. Remaining 172 records to reach 200 total records in bulk insert
        for (Integer i = 0; i < 172; i++) {
            // Spread across 172 distinct fake dates / offset months for empOther
            Date d = Date.newInstance(2025, 1, 1).addDays(i);
            attList.add(new Attendance__c(
                Employee__c = empOther.Id,
                Attendence_Date__c = d,
                Check_In__c = DateTime.newInstance(d.year(), d.month(), d.day(), 9, 0, 0),
                Status__c = 'Present'
            ));
        }

        System.assertEquals(200, attList.size(), 'Should have 200 total attendance records to insert');
        insert attList;

        Test.startTest();
        AttendanceDashboardController.AttendanceStatsWrapper stats = 
            AttendanceDashboardController.getMonthlyStats(emp.Id, targetMonth, targetYear);
        AttendanceDashboardController.AttendanceStatsWrapper statsDefaults = 
            AttendanceDashboardController.getMonthlyStats(emp.Id, null, null);
        AttendanceDashboardController.AttendanceStatsWrapper statsNullEmp = 
            AttendanceDashboardController.getMonthlyStats(null, targetMonth, targetYear);
        Test.stopTest();

        System.assertEquals(28, stats.totalDays, 'Total days should be 28');
        System.assertEquals(21, stats.presentCount, 'Present + WFH count should be 21');
        System.assertEquals(4, stats.absentCount, 'Absent count should be 4');
        System.assertEquals(3, stats.leaveCount, 'Leave count should be 3');
        System.assertEquals(75.0, stats.attendancePercentage, 'Attendance percentage should be (21/28)*100 = 75.0%');

        System.assertNotEquals(null, statsDefaults, 'Default params should return stats');
        System.assertEquals(0, statsNullEmp.totalDays, 'Null emp should return empty stats');
    }
}
