import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

import getTeamAttendancePercentage from '@salesforce/apex/TeamDashboardController.getTeamAttendancePercentage';
import getPendingLeaveRequests from '@salesforce/apex/TeamDashboardController.getPendingLeaveRequests';
import getEmployeesBelowThreshold from '@salesforce/apex/TeamDashboardController.getEmployeesBelowThreshold';
import getUpcomingInterviews from '@salesforce/apex/TeamDashboardController.getUpcomingInterviews';

export default class ManagerTeamDashboard extends NavigationMixin(LightningElement) {

    wiredAttResult;
    wiredLeavesResult;
    wiredLowAttResult;
    wiredInterviewsResult;

    @wire(getTeamAttendancePercentage)
    wiredAttendance(result) {
        this.wiredAttResult = result;
    }

    @wire(getPendingLeaveRequests)
    wiredLeaves(result) {
        this.wiredLeavesResult = result;
    }

    @wire(getEmployeesBelowThreshold)
    wiredLowAttendance(result) {
        this.wiredLowAttResult = result;
    }

    @wire(getUpcomingInterviews)
    wiredInterviews(result) {
        this.wiredInterviewsResult = result;
    }

    // --- Section 1: Team Attendance ---
    get isAttLoading() {
        return this.wiredAttResult?.data === undefined && !this.wiredAttResult?.error;
    }
    get hasAttError() {
        return !!this.wiredAttResult?.error;
    }
    get attErrorMessage() {
        return this.getErrorMessage(this.wiredAttResult?.error);
    }
    get teamAttendancePercentage() {
        return this.wiredAttResult?.data != null ? this.wiredAttResult.data : 0;
    }

    // --- Section 2: Low Attendance ---
    get isLowAttLoading() {
        return !this.wiredLowAttResult?.data && !this.wiredLowAttResult?.error;
    }
    get hasLowAttError() {
        return !!this.wiredLowAttResult?.error;
    }
    get lowAttErrorMessage() {
        return this.getErrorMessage(this.wiredLowAttResult?.error);
    }
    get lowAttendanceList() {
        return this.wiredLowAttResult?.data || [];
    }
    get isLowAttEmpty() {
        return this.lowAttendanceList.length === 0;
    }

    // --- Section 3: Pending Leaves ---
    get isLeavesLoading() {
        return !this.wiredLeavesResult?.data && !this.wiredLeavesResult?.error;
    }
    get hasLeavesError() {
        return !!this.wiredLeavesResult?.error;
    }
    get leavesErrorMessage() {
        return this.getErrorMessage(this.wiredLeavesResult?.error);
    }
    get pendingLeaves() {
        return this.wiredLeavesResult?.data || [];
    }
    get isLeavesEmpty() {
        return this.pendingLeaves.length === 0;
    }

    // --- Section 4: Upcoming Interviews ---
    get isInterviewsLoading() {
        return !this.wiredInterviewsResult?.data && !this.wiredInterviewsResult?.error;
    }
    get hasInterviewsError() {
        return !!this.wiredInterviewsResult?.error;
    }
    get interviewsErrorMessage() {
        return this.getErrorMessage(this.wiredInterviewsResult?.error);
    }
    get upcomingInterviews() {
        return this.wiredInterviewsResult?.data || [];
    }
    get isInterviewsEmpty() {
        return this.upcomingInterviews.length === 0;
    }

    // --- Refresh Handlers ---
    handleRefreshAttendance() {
        refreshApex(this.wiredAttResult);
    }
    handleRefreshLowAtt() {
        refreshApex(this.wiredLowAttResult);
    }
    handleRefreshLeaves() {
        refreshApex(this.wiredLeavesResult);
    }
    handleRefreshInterviews() {
        refreshApex(this.wiredInterviewsResult);
    }

    // --- Navigation Handler ---
    handleNavigateToEmployee(event) {
        const empId = event.target.dataset.id;
        if (empId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: empId,
                    objectApiName: 'Employee__c',
                    actionName: 'view'
                }
            });
        }
    }

    getErrorMessage(error) {
        if (!error) return '';
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (typeof error.body?.message === 'string') {
            return error.body.message;
        }
        return 'An error occurred while loading section data.';
    }
}
