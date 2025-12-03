/**
 * @description Base class for all trigger handlers
 * @author Ayush Srivastava
 */
public virtual class TriggerHandler {
    
    // Static map to prevent recursion
    private static Map<String, LoopCount> loopCountMap;
    private static Set<String> bypassedHandlers;
    
    // Instance variables
    @TestVisible
    private Boolean isTriggerExecuting;
    @TestVisible
    private TriggerContext context;
    
    // Static initialization
    static {
        loopCountMap = new Map<String, LoopCount>();
        bypassedHandlers = new Set<String>();
    }
    
    // Constructor
    public TriggerHandler() {
        this.setTriggerContext();
    }
    
    /**
     * @description Main entry point - called from trigger
     */
    public void run() {
        
        // Validate we should run
        if (!validateRun()) {
            return;
        }
        
        // Add to loop count
        addToLoopCount();
        
        // Route to appropriate method based on context
        switch on this.context {
            when BEFORE_INSERT {
                this.beforeInsert();
            }
            when BEFORE_UPDATE {
                this.beforeUpdate();
            }
            when BEFORE_DELETE {
                this.beforeDelete();
            }
            when AFTER_INSERT {
                this.afterInsert();
            }
            when AFTER_UPDATE {
                this.afterUpdate();
            }
            when AFTER_DELETE {
                this.afterDelete();
            }
            when AFTER_UNDELETE {
                this.afterUndelete();
            }
        }
    }
    
    // Virtual methods to override in subclasses
    @TestVisible
    protected virtual void beforeInsert() {}
    
    @TestVisible
    protected virtual void beforeUpdate() {}
    
    @TestVisible
    protected virtual void beforeDelete() {}
    
    @TestVisible
    protected virtual void afterInsert() {}
    
    @TestVisible
    protected virtual void afterUpdate() {}
    
    @TestVisible
    protected virtual void afterDelete() {}
    
    @TestVisible
    protected virtual void afterUndelete() {}
    
    /**
     * @description Bypass mechanism - allows disabling triggers
     */
    public static void bypass(String handlerName) {
        bypassedHandlers.add(handlerName);
    }
    
    public static void clearBypass(String handlerName) {
        bypassedHandlers.remove(handlerName);
    }
    
    public static Boolean isBypassed(String handlerName) {
        return bypassedHandlers.contains(handlerName);
    }
    
    public static void clearAllBypasses() {
        bypassedHandlers.clear();
    }
    
    /**
     * @description Loop count management
     */
    public void setMaxLoopCount(Integer max) {
        String handlerName = getHandlerName();
        if (!loopCountMap.containsKey(handlerName)) {
            loopCountMap.put(handlerName, new LoopCount(max));
        } else {
            loopCountMap.get(handlerName).setMax(max);
        }
    }
    
    public void clearMaxLoopCount() {
        loopCountMap.remove(getHandlerName());
    }
    
    // Private helper methods
    @TestVisible
    private void setTriggerContext() {
        if (!Trigger.isExecuting) {
            this.isTriggerExecuting = false;
            return;
        }
        
        this.isTriggerExecuting = true;
        
        if (Trigger.isBefore && Trigger.isInsert) {
            this.context = TriggerContext.BEFORE_INSERT;
        } else if (Trigger.isBefore && Trigger.isUpdate) {
            this.context = TriggerContext.BEFORE_UPDATE;
        } else if (Trigger.isBefore && Trigger.isDelete) {
            this.context = TriggerContext.BEFORE_DELETE;
        } else if (Trigger.isAfter && Trigger.isInsert) {
            this.context = TriggerContext.AFTER_INSERT;
        } else if (Trigger.isAfter && Trigger.isUpdate) {
            this.context = TriggerContext.AFTER_UPDATE;
        } else if (Trigger.isAfter && Trigger.isDelete) {
            this.context = TriggerContext.AFTER_DELETE;
        } else if (Trigger.isAfter && Trigger.isUndelete) {
            this.context = TriggerContext.AFTER_UNDELETE;
        }
    }
    
    private Boolean validateRun() {
        if (!this.isTriggerExecuting || this.context == null) {
            throw new TriggerHandlerException('Trigger handler called outside of trigger execution');
        }
        
        if (isBypassed(getHandlerName())) {
            return false;
        }
        
        return true;
    }
    
    private void addToLoopCount() {
        String handlerName = getHandlerName();
        if (loopCountMap.containsKey(handlerName)) {
            Boolean exceeded = loopCountMap.get(handlerName).increment();
            if (exceeded) {
                Integer max = loopCountMap.get(handlerName).max;
                throw new TriggerHandlerException('Maximum loop count of ' + max + ' reached for ' + handlerName);
            }
        }
    }
    
    @TestVisible
    private String getHandlerName() {
        return String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
    }
    
    // Inner classes
    @TestVisible
    private enum TriggerContext {
        BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE,
        AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE, AFTER_UNDELETE
    }
    
    @TestVisible
    private class LoopCount {
        private Integer max;
        private Integer count;
        
        public LoopCount() {
            this.max = 5;
            this.count = 0;
        }
        
        public LoopCount(Integer max) {
            this.max = max;
            this.count = 0;
        }
        
        public Boolean increment() {
            this.count++;
            return this.exceeded();
        }
        
        public Boolean exceeded() {
            return this.max >= 0 && this.count > this.max;
        }
        
        public void setMax(Integer max) {
            this.max = max;
        }
    }
    
    public class TriggerHandlerException extends Exception {}
}