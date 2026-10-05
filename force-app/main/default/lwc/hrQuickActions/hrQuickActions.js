import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { publish, MessageContext } from 'lightning/messageService';
import HR_ACTIONS_CHANNEL from '@salesforce/messageChannel/HRActions__c';

export default class HrQuickActions extends NavigationMixin(LightningElement) {

    @wire(MessageContext)
    messageContext;

    handleNewEmployee() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Employee__c',
                actionName: 'new'
            }
        });
    }

    handleScheduleInterview() {
        const payload = { actionName: 'scheduleInterview' };
        publish(this.messageContext, HR_ACTIONS_CHANNEL, payload);
    }

    handleMarkAttendance() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Attendance__c',
                actionName: 'new'
            }
        });
    }

    handleNewLeaveRequest() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Leave_Request__c',
                actionName: 'new'
            }
        });
    }

    handleViewReports() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Report',
                actionName: 'home'
            }
        });
    }
}
