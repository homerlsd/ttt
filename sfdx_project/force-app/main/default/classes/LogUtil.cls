public without sharing class LogUtil {

    //singleton instance
    private final testpharosx.Logger logger;
    public static LogUtil instance {
        get {
            if (instance == null) {
                instance = new LogUtil(testpharosx.Logger.getInstance());
            }
            return instance;
        }
        private set;
    }

    private LogUtil(testpharosx.Logger logger) {
        this.logger = logger;
    }

    /**
    * Log classification.
    * Use these enums to provide values for Category, Type and Functional Area fields on the log record.
    * These fields are useful for analytics and should be populated on all records.
    * Feel free to modify these or add new values as you see fit. It is best to stick to the
    * general spirit of the definition.
    */

    /**
    * Category.
    * Provides general classification. Defaults are Error, Warning, Event, Debug.
    * This value will be written to the Category field.
    * These values should reflect what kind of log entry they represent at a high level.
    */
    public enum Category {
        Error,
        Warning,
        Event,
        Debug,
        Integration
    }

    /**
    * Type.
    * Provides a more specific classification. This value will be written to the Type field.
    * Defaults are Backend and Frontend.
    * This value represents a more specific technical classification.
    * When an Exception is provided, the methods below will use the Exception type.
    */
    public enum Type {
        Backend,
        Frontend
    }

    /**
    * Area.
    * Represents the functional area. This value will be written to the Functional Area field.
    * These values should represent the functional area from a business perspective.
    * E.g. DealRegistration, PartnerCommunity, CustomPipelineUI.
    */
    public enum Area {
        OpportunityManagement,
        LeadConversion,
        Community
    }

    /**
    * Stack trace offset.
    * In case no stack is provided, it will be obtained automatically for error and debug logs.
    * Use the offset to remove unwanted lines from top of the stack trace
    * such as util method invocations.
    */
    private Integer stackOffset = 0;
    private void incStackOffset() {
        stackOffset++;
    }
    private void resetStackOffset() {
        stackOffset = 0;
    }

    /**
    * Buffered Log methods.
    * Use these methods to save Log records in bulk.
    * This is the preferred way of saving logs as it reduces the number of DML operations.
    * Generally, you want to capture all errors during execution and persist them at the
    * very end a routine's execution. Be sure to wrap your code with try/catch blocks.
    * Another good practice is to log from the 'finally' clause in your try/catches to ensure
    * that logs are saved no matter what happens within your code routine.
    * NOTE that you MUST call any of the flush methods below to actually save the data.
    */

    /**
    * Add Log with Error Category.
    * This method will automatically get the stacktrace and save it on the log record.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void addError(Type type, Area area, String summary, String details) {
        incStackOffset();
        this.logger.add(
                newBuilder()
                        .category(Category.Error.name())
                        .type(type.name())
                        .area(area.name())
                        .summary(summary)
                        .details(details)
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .build());
        resetStackOffset();
    }

    /**
    * Add Log with Error Category.
    * This method will automatically get the stacktrace from Exception.
    * Type will be obtained from Exception. If blank, a default Backend Type will be saved
    * Summary is the Exception message.
    * Details will be a combination of Exception String and stacktrace
    * @param area -- log record Functional Area (see Area enum)
    * @param e -- instance of an Exception
    */
    public void addError(Area area, Exception e) {
        this.logger.add(
                newBuilder()
                        .category(Category.Error.name())
                        //use exception type, Backend if blank
                        .type(String.isBlank(e.getTypeName()) ? Type.Backend.name() : e.getTypeName())
                        .area(area.name())
                        .summary(e.getMessage())
                        .stackTrace(e.getStackTraceString())
                        .details(String.valueOf(e) + SPACE_SEP + e.getStackTraceString())
                        .build());
    }

    /**
    * Add Log with Warning Category.
    * This method will not save a stacktrace.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void addWarning(Type type, Area area, String summary, String details) {
        this.logger.add(
                newBuilder()
                        .category(Category.Warning.name())
                        .type(type.name())
                        .area(area.name())
                        .summary(summary)
                        .details(details)
                        .build());
    }

    /**
    * Add Log with Debug Category.
    * This method will automatically get the stacktrace.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void addDebug(Type type, Area area, String summary, String details) {
        incStackOffset();
        this.logger.add(
                newBuilder()
                        .category(Category.Debug.name())
                        .type(type.name())
                        .area(area.name())
                        .summary(summary)
                        .details(details)
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .build());
        resetStackOffset();
    }

    /**
    * Add Log with Event Category.
    * This method will not save a stacktrace.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void addEvent(Type type, Area area, String summary, String details) {
        this.logger.add(
                newBuilder()
                        .category(Category.Event.name())
                        .type(type.name())
                        .area(area.name())
                        .summary(summary)
                        .details(details)
                        .build());
    }

    /**
    * Add Log with Integration Category.
    * This method will automatically get the stacktrace.
    * @param area -- log record Functional Area (see Area enum)
    * @param e -- instance of an Exception
    * @param request -- HttpRequest of the issue. Saves to log record Details field
    * @param response -- HttpResponse of the issue. Saves to log record Details field
    */
    public void addIntegration(Area area, Exception e, HttpRequest request, HttpResponse response) {
        this.logger.add(
                newBuilder()
                        .category(Category.Integration.name())
                        .type(String.isBlank(e.getTypeName()) ? Type.Backend.name() : e.getTypeName())
                        .area(area.name())
                        .summary(e.getMessage())
                        .details(String.valueOf(e) + SPACE_SEP + e.getStackTraceString())
                        .stackTrace(e.getStackTraceString())
                        .attribute('testpharosx__Stacktrace_Parse_Result__c', JSON.serialize(new IntegrationWrapper(
                                new testpharosx.HttpRequestWrapper(request).formatRequest(),
                                new testpharosx.HttpResponseWrapper(response).formatResponse()
                        )))
                        .build());
    }

    /**
    * Add Log with Integration Category.
    * This method will automatically get the stacktrace.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    * @param request -- HttpRequest of the issue. Saves to log record Details field
    * @param response -- HttpResponse of the issue. Saves to log record Details field
    */
    public void addIntegration(Type type, Area area, String summary, String details, HttpRequest request, HttpResponse response) {
        incStackOffset();
        this.logger.add(
                newBuilder()
                        .category(Category.Integration.name())
                        .type(type.name())
                        .area(area.name())
                        .summary(summary)
                        .details(details)
                        .stackTrace(this.logger.getCurrentStackTrace(stackOffset))
                        .attribute('testpharosx__Stacktrace_Parse_Result__c', JSON.serialize(new IntegrationWrapper(
                                new testpharosx.HttpRequestWrapper(request).formatRequest(),
                                new testpharosx.HttpResponseWrapper(response).formatResponse()
                        )))
                        .build());
        resetStackOffset();
    }

    /**
    * Immediate Single Log methods.
    * Use these methods to save a single Log record right away without any buffering.
    * These methods can be used when there is a single Log record to be saved.
    * Generally, it is best to buffer logs and save them at the end of execution.
    * However, there are rare cases when a log record should be immediately persisted
    * such as when code execution could fail after the log statement.
    * NOTE that you do NOT need to call any of flush methods afterwards.
    */


    /**
    * Save Log with Error Category.
    * This method will automatically get the stacktrace and save it on the log record.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void error(Type type, Area area, String summary, String details) {
        incStackOffset();
        addError(type, area, summary, details);
        flush();
    }

    /**
    * Save Log with Error Category.
    * This method will automatically get the stacktrace from Exception.
    * Type will be obtained from Exception. If blank, a default Backend Type will be saved
    * Summary is the Exception message.
    * Details will be a combination of Exception String and stacktrace
    * @param area -- log record Functional Area (see Area enum)
    * @param e -- instance of an Exception
    */
    public void error(Area area, Exception e) {
        addError(area, e);
        flush();
    }

    /**
    * Save Log with Warning Category.
    * This method will not save a stacktrace.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void warning(Type type, Area area, String summary, String details) {
        addWarning(type, area, summary, details);
        flush();
    }

    /**
    * Save Log with Debug Category.
    * This method will automatically get the stacktrace.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void debug(Type type, Area area, String summary, String details) {
        incStackOffset();
        addDebug(type, area, summary, details);
        flush();
    }

    /**
    * Save Log with Event Category.
    * This method will not save a stacktrace.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void event(Type type, Area area, String summary, String details) {
        addEvent(type, area, summary, details);
        flush();
    }

    /**
    * Save Log with Integration Category.
    * This method will automatically get the stacktrace.
    * @param area -- log record Functional Area (see Area enum)
    * @param e -- instance of an Exception
    * @param request -- HttpRequest of the issue. Saves to log record Details field
    * @param response -- HttpResponse of the issue. Saves to log record Details field
    */
    public void integration(Area area, Exception e, HttpRequest request, HttpResponse response) {
        addIntegration(area, e, request, response);
        flush();
    }

    /**
    * Save Log with Integration Category.
    * This method will automatically get the stacktrace.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    * @param request -- HttpRequest of the issue. Saves to log record Details field
    * @param response -- HttpResponse of the issue. Saves to log record Details field
    */
    public void integration(Type type, Area area, String summary, String details, HttpRequest request, HttpResponse response) {
        incStackOffset();
        addIntegration(type, area, summary, details, request, response);
        flush();
    }

    /**
    * Asynchronous Single Log methods.
    * Use these methods to save a single Log record asynchronously without any buffering.
    * These methods can be used when there is a single Log record to be saved and either no DML can or should be
    * performed afterwards. A typical example would be logging right before a callout.
    * NOTE that you do NOT need to call any of flush methods afterwards.
    */

    /**
    * Save Log with Error Category in a Queueable.
    * This method will automatically get the stacktrace and save it on the log record.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void errorAsync(Type type, Area area, String summary, String details) {
        incStackOffset();
        addError(type, area, summary, details);
        flushAsync();
    }

    /**
    * Save Log with Error Category in a Queueable.
    * This method will automatically get the stacktrace from Exception.
    * Type will be obtained from Exception. If blank, a default Backend Type will be saved
    * Summary is the Exception message.
    * Details will be a combination of Exception String and stacktrace
    * @param area -- log record Functional Area (see Area enum)
    * @param e -- instance of an Exception
    */
    public void errorAsync(Area area, Exception e) {
        addError(area, e);
        flushAsync();
    }

    /**
    * Save Log with Warning Category in a Queueable.
    * This method will not save a stacktrace.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void warningAsync(Type type, Area area, String summary, String details) {
        addWarning(type, area, summary, details);
        flushAsync();
    }

    /**
    * Save Log with Debug Category in a Queueable.
    * This method will automatically get the stacktrace.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void debugAsync(Type type, Area area, String summary, String details) {
        incStackOffset();
        addDebug(type, area, summary, details);
        flushAsync();
    }

    /**
    * Save Log with Event Category in a Queueable.
    * This method will not save a stacktrace.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    */
    public void eventAsync(Type type, Area area, String summary, String details) {
        addEvent(type, area, summary, details);
        flushAsync();
    }

    /**
    * Save Log with Integration Category in a Queueable.
    * This method will automatically get the stacktrace.
    * @param area -- log record Functional Area (see Area enum)
    * @param e -- instance of an Exception
    * @param request -- HttpRequest of the issue. Saves to log record Details field
    * @param response -- HttpResponse of the issue. Saves to log record Details field
    */
    public void integrationAsync(Area area, Exception e, HttpRequest request, HttpResponse response) {
        addIntegration(area, e, request, response);
        flushAsync();
    }

    /**
    * Save Log with Integration Category in a Queueable.
    * This method will automatically get the stacktrace.
    * @param type -- log record Type (see Type enum)
    * @param area -- log record Functional Area (see Area enum)
    * @param summary -- summary of the issue. Saves to log record Summary field
    * @param details -- details of the issue. Saves to log record Details field
    * @param request -- HttpRequest of the issue. Saves to log record Details field
    * @param response -- HttpResponse of the issue. Saves to log record Details field
    */
    public void integrationAsync(Type type, Area area, String summary, String details, HttpRequest request, HttpResponse response) {
        incStackOffset();
        addIntegration(type, area, summary, details, request, response);
        flushAsync();
    }

    /**
    * Buffer Operations.
    * Use these methods to persist logs to the database.
    * Pharos uses Platform Events so regardless of failures after the log statement,
    * all logs are guaranteed to be persisted. There are also no possibilities for
    * 'mixed dml' operations so you can perform dml on any object prior to logging.
    */

    /**
    * Persist Log records immediately.
    * Use this method to persist logs to the database right away.
    */
    public void flush() {
        this.logger.flush();
    }

    /**
    * Persist Log records in a Queueable.
    * Use this method to persist logs to the database asynchronously.
    * Can be used when immediate execution is not a concern or when no DML is possible or desired
    * after the flush.
    */
    public void flushAsync() {
        this.logger.flushAsync();
    }

    // LogBuilder
    public static testpharosx.LogBuilder newBuilder() {
        return testpharosx.LogBuilder.getInstance();
    }

    //new line separator for formatting
    private static final String SPACE_SEP = '\n\n';

    public class IntegrationWrapper {
        public Map<String, Object> request;
        public Map<String, Object> response;
        public IntegrationWrapper(Map<String, Object> request, Map<String, Object> response) {
            this.request = request;
            this.response = response;
        }
    }

}