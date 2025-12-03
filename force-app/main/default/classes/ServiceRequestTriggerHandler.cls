/**
 * @description Trigger handler for Service_Request__c object
 * @author Ayush Srivastava
 */
public class ServiceRequestTriggerHandler extends TriggerHandler {
    
    // Instance variables - strongly typed for this object
    private List<Service_Request__c> newRequests;
    private List<Service_Request__c> oldRequests;
    private Map<Id, Service_Request__c> newRequestMap;
    private Map<Id, Service_Request__c> oldRequestMap;
    
    /**
     * @description Constructor - casts Trigger context variables
     */
    public ServiceRequestTriggerHandler() {
        // Cast generic Trigger.new to our specific object type
        this.newRequests = (List<Service_Request__c>) Trigger.new;
        this.oldRequests = (List<Service_Request__c>) Trigger.old;
        this.newRequestMap = (Map<Id, Service_Request__c>) Trigger.newMap;
        this.oldRequestMap = (Map<Id, Service_Request__c>) Trigger.oldMap;
    }
    
    /**
     * @description BEFORE INSERT - runs before new records are saved
     * Good for: setting default values, validation
     */
    protected override void beforeInsert() {
        // Call service layer methods
        ServiceRequestService.setDefaultValues(this.newRequests);
        ServiceRequestService.validateRequiredFields(this.newRequests);
    }
    
    /**
     * @description BEFORE UPDATE - runs before records are updated
     * Good for: validation, preventing invalid changes
     */
    protected override void beforeUpdate() {
        ServiceRequestService.validateStatusTransitions(this.newRequests, this.oldRequestMap);
    }
    
    /**
     * @description AFTER INSERT - runs after new records are saved
     * Good for: creating related records, sending notifications
     */
    protected override void afterInsert() {
        ServiceRequestService.autoAssignAgents(this.newRequests);
        ServiceRequestService.sendNotifications(this.newRequests);
    }
    
    /**
     * @description AFTER UPDATE - runs after records are updated
     * Good for: updating related records, logging changes
     */
    protected override void afterUpdate() {
        // Only process records where status changed
        List<Service_Request__c> statusChanged = filterStatusChanged();
        
        if (!statusChanged.isEmpty()) {
            ServiceRequestService.handleStatusChange(statusChanged, this.oldRequestMap);
        }
    }
    
    /**
     * @description Helper method - filters records where status changed
     */
    private List<Service_Request__c> filterStatusChanged() {
        List<Service_Request__c> result = new List<Service_Request__c>();
        
        for (Service_Request__c newReq : this.newRequests) {
            Service_Request__c oldReq = this.oldRequestMap.get(newReq.Id);
            
            // Check if status is different
            if (newReq.Status__c != oldReq.Status__c) {
                result.add(newReq);
            }
        }
        
        return result;
    }
}