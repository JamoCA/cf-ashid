component {
	this.name = "ashidVectorGen_" & hash(getCurrentTemplatePath());
	this.sessionManagement = false;
	this.setClientCookies = false;

	rootPath = expandPath("../../");

	this.mappings["/ashid"] = rootPath;
}
