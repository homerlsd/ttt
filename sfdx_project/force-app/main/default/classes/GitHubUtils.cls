public with sharing class GitHubUtils implements Database.Batchable<String>, Database.Stateful, Database.AllowsCallouts  {

    public GitHubUtils() {
    
    }
    
    public Iterable<String> start(Database.BatchableContext BC) {
        return new List<String>{'BatchIteration'};
    }
    
    public void execute(Database.BatchableContext BC, List<String> scope) {
        String base64Response = GitHubUtils.getRetrieveRequestZipFile('09S6g0000090nTXEAY');

        Blob tinyZip = EncodingUtil.base64Decode(base64Response);
        ZipUtil testZippex = new ZipUtil(tinyZip);
        //system.debug(testZippex.getFileNames());
        system.debug(testZippex.getFile('classes/MetadataService.cls').toString());
    }

    public void finish(Database.BatchableContext BC) {
    }

    public static final Integer METADATA_API_VERSION = 51;

    public static MetadataService.MetadataPort getMetadataService() {
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        service.SessionHeader.sessionId = UserInfo.getSessionId();
        return service;
    }

    public static MetadataService.AsyncResult submitRetrieveRequest() {
        MetadataService.RetrieveRequest retrieveRequest = createRetrieveRequest('ApexClass', new String[] {'MetadataService'});
        MetadataService.AsyncResult asyncResult = getMetadataService().retrieve(retrieveRequest);
        system.debug('--asyncResult--'+asyncResult);
        return asyncResult;
    }

    public static MetadataService.RetrieveRequest createRetrieveRequest(String metadataType, String[] members) {
        MetadataService.RetrieveRequest retrieveRequest = new MetadataService.RetrieveRequest();
        retrieveRequest.apiVersion = METADATA_API_VERSION;
        retrieveRequest.packageNames = null;
        retrieveRequest.singlePackage = true;
        retrieveRequest.specificFiles = null;
        retrieveRequest.unpackaged = new MetadataService.Package_x();
        retrieveRequest.unpackaged.types = new List<MetadataService.PackageTypeMembers>();
        MetadataService.PackageTypeMembers packageType = new MetadataService.PackageTypeMembers();
        packageType.name = metadataType;
        packageType.members = members;
        retrieveRequest.unpackaged.types.add(packageType);

        return retrieveRequest;
    }

    public static String getRetrieveRequestZipFile(String requestId) {
        MetadataService.RetrieveResult retrieveResult = getMetadataService().checkRetrieveStatus(requestId, true);
        system.debug(json.serialize(retrieveResult.zipFile));
        return retrieveResult.zipFile;
        //system.debug(retrieveResult.zipFile);
        //system.debug(json.serialize(retrieveResult.zipFile));
    }
}