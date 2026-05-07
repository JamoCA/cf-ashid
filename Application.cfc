component {
	this.name = "ashidDemo_" & hash(getCurrentTemplatePath());
	this.sessionManagement = false;
	this.setClientCookies = false;
	this.mappings["/ashid"] = getDirectoryFromPath(getCurrentTemplatePath());
}
