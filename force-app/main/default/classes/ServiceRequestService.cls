/**
 * @description Service layer for Service Request business logic
 * @author Ayush Srivastava
 */
public with sharing class ServiceRequestService {
    
    /**
     * @description Sets default values on new Service Requests
     * @param requests List of new Service Requests
     */
    public static void setDefaultValues(List<Service_Request__c> requests) {
        
        for (Service_Request__c req : requests) {
            
            // Set default status if not provided
            if (String.isBlank(req.Status__c)) {
                req.Status__c = 'New';
            }
            
            // Set default priority if not provided
            if (String.isBlank(req.Priority__c)) {
                req.Priority__c = 'Medium';
            }
            
            // Set due date to 3 days from now if not provided
            if (req.Due_Date__c == null) {
                req.Due_Date__c = System.now().addDays(3);
            }
        }
    }
    
    /**
     * @description Validates required fields are populated
     * @param requests List of Service Requests to validate
     */
    public static void validateRequiredFields(List<Service_Request__c> requests) {
        
        for (Service_Request__c req : requests) {
            
            // Ensure customer email is provided
            if (String.isBlank(req.Customer_Email__c)) {
                req.addError('Customer Email is required');
            }
            
            // Ensure description is provided
            // TEMPORARILY DISABLED: LongTextArea fields cannot be marked required in metadata
            // Will enable after fixing page layout to show Description field
            /*
            if (String.isBlank(req.Description__c)) {
                req.addError('Description is required');
            }
            */
        }
    }
    
    /**
     * @description Validates status transitions are allowed
     * @param newRequests List of updated Service Requests
     * @param oldRequestMap Map of old values before update
     */
    public static void validateStatusTransitions(
        List<Service_Request__c> newRequests,
        Map<Id, Service_Request__c> oldRequestMap
    ) {
        
        // Define valid status transitions
        Map<String, Set<String>> validTransitions = new Map<String, Set<String>>{
            'New' => new Set<String>{'In Progress', 'Pending Customer', 'Closed'},
            'In Progress' => new Set<String>{'Pending Customer', 'Resolved', 'Escalated'},
            'Pending Customer' => new Set<String>{'In Progress', 'Closed'},
            'Escalated' => new Set<String>{'In Progress', 'Resolved'},
            'Resolved' => new Set<String>{'Closed', 'In Progress'},
            'Closed' => new Set<String>()  // Cannot change from Closed
        };
        
        for (Service_Request__c newReq : newRequests) {
            Service_Request__c oldReq = oldRequestMap.get(newReq.Id);
            
            // Check if status changed
            if (newReq.Status__c != oldReq.Status__c) {
                
                Set<String> allowedStatuses = validTransitions.get(oldReq.Status__c);
                
                // Validate the transition is allowed
                if (allowedStatuses == null || !allowedStatuses.contains(newReq.Status__c)) {
                    newReq.addError(
                        'Invalid status transition from "' + oldReq.Status__c + 
                        '" to "' + newReq.Status__c + '"'
                    );
                }
            }
        }
    }
    
    /**
     * @description Auto-assigns Service Requests to available agents
     * @param requests List of new Service Requests
     */
    public static void autoAssignAgents(List<Service_Request__c> requests) {
        
        // Get list of active agents
        List<Service_Agent__c> availableAgents = [
            SELECT Id, Name, Email__c, Department__c
            FROM Service_Agent__c
            WHERE Is_Active__c = true
            ORDER BY Name
        ];
        
        if (availableAgents.isEmpty()) {
            return; // No agents available
        }
        
        List<Service_Assignment__c> assignmentsToCreate = new List<Service_Assignment__c>();
        Integer agentIndex = 0;
        
        // Round-robin assignment
        for (Service_Request__c req : requests) {
            
            // Only auto-assign if priority is High or Critical
            if (req.Priority__c == 'High' || req.Priority__c == 'Critical') {
                
                Service_Agent__c agent = availableAgents[agentIndex];
                
                // Create assignment record
                Service_Assignment__c assignment = new Service_Assignment__c(
                    Service_Request__c = req.Id,
                    Service_Agent__c = agent.Id,
                    Assigned_Date__c = Date.today(),
                    Notes__c = 'Auto-assigned based on priority: ' + req.Priority__c
                );
                
                assignmentsToCreate.add(assignment);
                
                // Move to next agent (round-robin)
                agentIndex++;
                if (agentIndex >= availableAgents.size()) {
                    agentIndex = 0; // Wrap around
                }
            }
        }
        
        if (!assignmentsToCreate.isEmpty()) {
            insert assignmentsToCreate;
        }
    }
    
    /**
     * @description Sends email notifications for new requests
     * @param requests List of new Service Requests
     */
    public static void sendNotifications(List<Service_Request__c> requests) {
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (Service_Request__c req : requests) {
            
            // Create email for customer
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[]{req.Customer_Email__c});
            email.setSubject('Service Request Created: ' + req.Name);
            email.setPlainTextBody(
                'Thank you for contacting us!\n\n' +
                'Your service request has been created with the following details:\n\n' +
                'Request Number: ' + req.Name + '\n' +
                'Priority: ' + req.Priority__c + '\n' +
                'Status: ' + req.Status__c + '\n' +
                'Due Date: ' + req.Due_Date__c.format() + '\n\n' +
                'We will keep you updated on the progress.\n\n' +
                'Best regards,\n' +
                'Support Team'
            );
            
            emails.add(email);
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
    
    /**
     * @description Handles status change logic
     * @param requests List of Service Requests with status changes
     * @param oldRequestMap Map of old values
     */
    public static void handleStatusChange(
        List<Service_Request__c> requests,
        Map<Id, Service_Request__c> oldRequestMap
    ) {
        
        for (Service_Request__c req : requests) {
            
            // If marked as Resolved, require resolution notes
            if (req.Status__c == 'Resolved' && String.isBlank(req.Resolution_Notes__c)) {
                req.addError('Resolution Notes are required when marking as Resolved');
            }
            
            // Log status change (in real app, you might create a history record)
            System.debug('Status changed for ' + req.Name + ': ' + 
                        oldRequestMap.get(req.Id).Status__c + ' → ' + req.Status__c);
        }
    }
}