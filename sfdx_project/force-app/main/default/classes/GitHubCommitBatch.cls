public with sharing class GitHubCommitBatch implements Database.batchable<MetadataTypeWrapper>,Database.Stateful, Database.AllowsCallouts,Database.RaisesPlatformEvents {

	public Enum BATCH_MODE {
		SUBMIT_RETRIEVE_REQUEST,
		PROCESS_METADATA_ITEMS
	}
	private BATCH_MODE currentMode;
	private String refPath;
	private List<MetadataTypeWrapper> incompletedPackageItems = new List<MetadataTypeWrapper>();

	public GitHubCommitBatch() {
		this(BATCH_MODE.SUBMIT_RETRIEVE_REQUEST);
	}

	public GitHubCommitBatch(BATCH_MODE batchMode) {
		this.currentMode = batchMode;
	}

	public GitHubCommitBatch(BATCH_MODE batchMode, List<MetadataTypeWrapper> incompletedPackageItems) {
		this.currentMode = batchMode;
		this.incompletedPackageItems = incompletedPackageItems;
	}

	public Iterable<MetadataTypeWrapper> start(Database.BatchableContext bc) {
		MetadataTypeIterable iterable;

		if(this.currentMode == BATCH_MODE.SUBMIT_RETRIEVE_REQUEST) {
			iterable = new MetadataTypeIterable(getMetadataTypeMembers());
		}
		else if(this.currentMode == BATCH_MODE.PROCESS_METADATA_ITEMS) {
			if(!this.incompletedPackageItems.isEmpty()) {
				iterable = new MetadataTypeIterable(this.incompletedPackageItems);
				this.incompletedPackageItems.clear();
			}
			else {
				iterable = new MetadataTypeIterable(getMetadataPackageItemsFromCache());
			}
		}
		return iterable;
	}

	public void execute(Database.batchableContext info, List<MetadataTypeWrapper> scope) {
		switch on this.currentMode {
			when SUBMIT_RETRIEVE_REQUEST {
				List<MetadataTypeWrapper> scopeItems = (List<MetadataTypeWrapper>)scope;
				List<MetadataTypeWrapper> retrieveItems = GitHubUtils.createSubmitRetrieveRequest(scopeItems.get(0));
				if(!retrieveItems.isEmpty()) {
					putMetadataPackageItemsToCache(retrieveItems);
				}
			}
			when PROCESS_METADATA_ITEMS {
				List<MetadataTypeWrapper> scopeItems = (List<MetadataTypeWrapper>)scope;
				List<GitHubUtils.SourceMetadataFile> files = GitHubUtils.processMetadataItems(scopeItems.get(0));
				if(files.isEmpty()) {
					this.incompletedPackageItems.add(scopeItems.get(0));
				}
				else {
					this.refPath = GitHubUtils.makeCommit(files, this.refPath);
				}
			}
		}
	}

	public void finish(Database.BatchableContext BC) {
		switch on this.currentMode {
			when SUBMIT_RETRIEVE_REQUEST {
				Database.executeBatch(new GitHubCommitBatch(BATCH_MODE.PROCESS_METADATA_ITEMS), 1);
			}
			when PROCESS_METADATA_ITEMS {
				if(!this.incompletedPackageItems.isEmpty()) {
					Database.executeBatch(new GitHubCommitBatch(BATCH_MODE.PROCESS_METADATA_ITEMS, this.incompletedPackageItems), 1);
				}
				else if(String.isNotBlank(this.refPath)) {
					Integer pullNumber = GitHubUtils.gitCreatePullRequest();
					Boolean isMerged = GitHubUtils.gitCreateMergePullRequest(pullNumber, GitHubUtils.GIT_API_DEFAULT_MERGE_COMMIT_TITLE);
				}
			}
		}
	}

	public class MetadataTypeIterable implements Iterable<MetadataTypeWrapper> {

		private List<MetadataTypeWrapper> packageItems;

		public MetadataTypeIterable() {
			this.packageItems = new List<MetadataTypeWrapper>();
		}

		public MetadataTypeIterable(List<MetadataTypeWrapper> packageItems) {
			this.packageItems = packageItems;
		}

		public Iterator<MetadataTypeWrapper> iterator() {
			return new MetadataTypeIterator(this.packageItems);
		}
	}

	public class MetadataTypeIterator implements Iterator<MetadataTypeWrapper> {
		private List<MetadataTypeWrapper> packageItems;
		private Integer index;

		public MetadataTypeIterator(List<MetadataTypeWrapper> defaults) {
			this.packageItems = defaults == null ? new List<MetadataTypeWrapper>() : defaults;
			this.index = 0;
		}

		public MetadataTypeIterator() {
			this(new List<MetadataTypeWrapper>());
		}

		public Boolean hasNext() {
			return this.index < packageItems.size() ? true : false;
		}

		public MetadataTypeWrapper next() {
			return this.packageItems[this.index++];
		}
	}

	public static final String METADATA_TYPE_FLOW = 'Flow';
	public static final String METADATA_TYPE_APEX_CLASS = 'ApexClass';
	public static final String METADATA_TYPE_APEX_TRIGGER = 'ApexTrigger';
	public static final String METADATA_TYPE_CUSTOM_OBJECT = 'CustomObject';

	public static List<MetadataTypeWrapper> getMetadataTypeMembers() {
		List<MetadataTypeWrapper> result = new List<MetadataTypeWrapper>();
		// return all metadata items
		if(String.isBlank(ConfigUtil.GIT_API_SETTINGS.Last_Processed_Id__c)) {
			result = getDefaultMetadataTypeMembers();
		}
		else {
			List<SetupAuditTrail> changedItems = getAuditTrails(ConfigUtil.GIT_API_SETTINGS.Last_Processed_Id__c);
			if(!changedItems.isEmpty()) {
				result = getFilteredMetadataTypeMembers(changedItems);
				setLastProcessedId(changedItems);
			}
		}
		return result;
	}

	public static void setLastProcessedId(List<SetupAuditTrail> changedItems) {
		if(!changedItems.isEmpty()) {
			Integer lastIndex = changedItems.size() - 1;
			ConfigUtil.GIT_API_SETTINGS.Last_Processed_Id__c = changedItems.get(lastIndex).Id;
			update ConfigUtil.GIT_API_SETTINGS;
		}
	}

	public static final String AUDIT_TRAIL_SECTION_APEX_CLASS = 'Apex Class';
	public static final String AUDIT_TRAIL_SECTION_APEX_TRIGGER = 'Apex Trigger';
	public static final String AUDIT_TRAIL_SECTION_FLOWS = 'Flows';
	public static final String AUDIT_TRAIL_SECTION_CUSTOM_OBJECTS = 'Custom Objects';

	public static List<MetadataTypeWrapper> getFilteredMetadataTypeMembers(List<SetupAuditTrail> changedItems) {
		List<MetadataTypeWrapper> result = new List<MetadataTypeWrapper>();
		List<ApexClass> apexClasses = getListApexClasses();
		List<ApexTrigger> apexTriggers = getListApexTriggers();
		List<FlowDefinitionView> flows = getListFlows();

		MetadataTypeWrapperContainer apexClassContainer = new MetadataTypeWrapperContainer();
		MetadataTypeWrapperContainer apexTriggerContainer = new MetadataTypeWrapperContainer();

		for(SetupAuditTrail auditTrail : changedItems) {
			if(auditTrail.Section == AUDIT_TRAIL_SECTION_APEX_CLASS) {
				for(ApexClass ac : apexClasses) {
					if(auditTrail.Display.containsIgnoreCase(ac.Name)) {
						apexClassContainer.addMember(METADATA_TYPE_APEX_CLASS, ac.Name, ac.LengthWithoutComments);
					}
				}
			}
			else if(auditTrail.Section == AUDIT_TRAIL_SECTION_APEX_TRIGGER) {
				for(ApexTrigger at : apexTriggers) {
					if(auditTrail.Display.containsIgnoreCase(at.Name)) {
						apexTriggerContainer.addMember(METADATA_TYPE_APEX_TRIGGER, at.Name, at.LengthWithoutComments);
					}
				}
			}
			else if(auditTrail.Section == AUDIT_TRAIL_SECTION_FLOWS) {
				for(FlowDefinitionView fdv : flows) {
					if(auditTrail.Display.containsIgnoreCase(fdv.ApiName)) {
						result.add(new MetadataTypeWrapper(METADATA_TYPE_FLOW, fdv.ApiName));
					}
				}
			}
		}
		if(!apexClassContainer.members.isEmpty()) {
			result.addAll(apexClassContainer.members);
		}
		if(!apexTriggerContainer.members.isEmpty()) {
			result.addAll(apexTriggerContainer.members);
		}
		if(!changedItems.isEmpty()) {
			result.add(new MetadataTypeWrapper(METADATA_TYPE_CUSTOM_OBJECT, '*'));
		}
		return result;
	}

	public static List<SetupAuditTrail> getAuditTrails(String lastProcessedId) {
		List<SetupAuditTrail> result = [
			SELECT Id, Action, CreatedDate, Display, Section
			FROM SetupAuditTrail
			WHERE Id > :lastProcessedId
			ORDER BY CreatedDate DESC
		];
		return result;
	}

	public static List<FlowDefinitionView> getListFlows() {
		List<FlowDefinitionView> result = [
			SELECT ApiName, NamespacePrefix, Label, IsActive
			FROM FlowDefinitionView
			WHERE NamespacePrefix = NULL
				OR NamespacePrefix = :ConfigUtil.currentOrgNameSpacePrefix
		];
		return result;
	}

	public static List<ApexClass> getListApexClasses() {
		List<ApexClass> result = [
			SELECT LengthWithoutComments, NamespacePrefix, Name
			FROM ApexClass
			WHERE NamespacePrefix = NULL
				OR NamespacePrefix = :ConfigUtil.currentOrgNameSpacePrefix
		];
		return result;
	}

	public static List<ApexTrigger> getListApexTriggers() {
		List<ApexTrigger> result = [
			SELECT LengthWithoutComments, NamespacePrefix, Name
			FROM ApexTrigger
			WHERE NamespacePrefix = NULL
			OR NamespacePrefix = :ConfigUtil.currentOrgNameSpacePrefix
		];
		return result;
	}

	public static List<MetadataTypeWrapper> getDefaultMetadataTypeMembers() {
		List<MetadataTypeWrapper> result = new List<MetadataTypeWrapper>();
		result.add(new MetadataTypeWrapper(METADATA_TYPE_FLOW, '*'));
		result.add(new MetadataTypeWrapper(METADATA_TYPE_CUSTOM_OBJECT, '*'));

		MetadataTypeWrapperContainer apexClassContainer = new MetadataTypeWrapperContainer();
		MetadataTypeWrapperContainer apexTriggerContainer = new MetadataTypeWrapperContainer();

		for(ApexClass ac : getListApexClasses()) {
			apexClassContainer.addMember(METADATA_TYPE_APEX_CLASS, ac.Name, ac.LengthWithoutComments);
			//system.debug(apexClassContainer.memeber.size());
		}
		for(ApexTrigger at : getListApexTriggers()) {
			apexTriggerContainer.addMember(METADATA_TYPE_APEX_TRIGGER, at.Name, at.LengthWithoutComments);
		}

		if(!apexClassContainer.members.isEmpty()) {
			result.addAll(apexClassContainer.members);
		}
		if(!apexTriggerContainer.members.isEmpty()) {
			result.addAll(apexTriggerContainer.members);
		}

		return result;
	}

	public static List<MetadataTypeWrapper> getMetadataPackageItemsFromCache() {
		CacheUtils cacheUtil = new CacheUtils('');
		Object cacheObject = cacheUtil.getValue(CacheUtils.KEY_REQUEST_METADATA_RETRIEVE_REQUEST);
		return (List<MetadataTypeWrapper>)cacheObject;
	}

	public static void putMetadataPackageItemsToCache(List<MetadataTypeWrapper> packageItems) {
		CacheUtils cacheUtil = new CacheUtils('');
		List<MetadataTypeWrapper> existPackageItems = getMetadataPackageItemsFromCache();
		if(existPackageItems == null || existPackageItems.isEmpty()) {
			existPackageItems = new List<MetadataTypeWrapper>();
		}
		existPackageItems.addAll(packageItems);
		cacheUtil.putValue(CacheUtils.KEY_REQUEST_METADATA_RETRIEVE_REQUEST, existPackageItems);
	}

	public static final Integer METADATA_CONTAINER_ITEM_MAX_SIZE = 1000000; //1mb

	public class MetadataTypeWrapperContainer {
		public List<MetadataTypeWrapper> members;
		public Integer currentContainerSize = 0;

		public MetadataTypeWrapperContainer() {
			this.members = new List<MetadataTypeWrapper>();
		}

		public void addMember(String type, String member, Integer size) {
			if(!this.members.isEmpty()
				&& this.currentContainerSize <= METADATA_CONTAINER_ITEM_MAX_SIZE
				&& (this.currentContainerSize + size) <= METADATA_CONTAINER_ITEM_MAX_SIZE) {

				Integer lastIndex = this.members.size() == 0 ? 0 : this.members.size() - 1;
				this.currentContainerSize = this.currentContainerSize + size;
				this.members.get(lastIndex).addMember(member);
			}
			else {
				this.currentContainerSize = 0;
				this.members.add(new MetadataTypeWrapper(type, member));
			}
		}
	}

	public class MetadataTypeWrapper {
		public String jobId;
		public String type;
		public List<String> member;

		public MetadataTypeWrapper(String type, String member) {
			this.type = type;
			this.member = new List<String>{member};
		}

		public void addMember(String member) {
			this.member.add(member);
		}
	}
}