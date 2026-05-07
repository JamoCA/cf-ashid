component {
	this.name = "ashidBenchmark_" & hash(getCurrentTemplatePath());
	this.sessionManagement = false;
	this.setClientCookies = false;
	this.mappings["/ashid"] = expandPath("../");
}
