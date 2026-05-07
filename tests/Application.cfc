component {
	this.name = "ashidTests_" & hash(getCurrentTemplatePath());
	this.sessionManagement = false;
	this.setClientCookies = false;

	appDir   = getDirectoryFromPath(getCurrentTemplatePath());
	rootPath = getCanonicalPath(appDir & ("../"));

	this.mappings["/ashid"] = rootPath;
}
