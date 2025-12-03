/**
 * @description Trigger for Service_Request__c object
 * All logic delegated to handler class
 */
trigger ServiceRequestTrigger on Service_Request__c (
    before insert, before update, before delete,
    after insert, after update, after delete, after undelete
) {
    new ServiceRequestTriggerHandler().run();
}