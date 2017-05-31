<h1 class="page-header">Scan Summary</h1>
<div class="col-sm-12 col-md-12 main">
	<div class="table-responsive">
		<div class="panel panel-default">
			<div class="panel-heading">
				<h3 class="panel-title">Scans</h3>
			</div>
			<div class="panel-body">
				[[wwwroot\views\packageManager\scans\tabList.tpl]] 
				
				<div class="tab-content" id="myTabContent" style="min-height:400px;">
					[[wwwroot\views\packageManager\scans\summary.tpl]] 
					[[wwwroot\views\packageManager\scans\oldCkls.tpl]] 
					[[wwwroot\views\packageManager\scans\oldAcas.tpl]] 
					[[wwwroot\views\packageManager\scans\nonCred.tpl]] 
					[[wwwroot\views\packageManager\scans\acasHostMismatch.tpl]] 
					[[wwwroot\views\packageManager\scans\cklReqNotReviewed.tpl]] 
					[[wwwroot\views\packageManager\scans\cklOver10.tpl]] 
					[[wwwroot\views\packageManager\scans\cklMissing.tpl]] 					
					[[wwwroot\views\packageManager\scans\oldScap.tpl]] 
					[[wwwroot\views\packageManager\scans\scapBelow90.tpl]] 
					[[wwwroot\views\packageManager\scans\scapHostMismatch.tpl]] 
					[[wwwroot\views\packageManager\scans\scapNoCkl.tpl]] 
					[[wwwroot\views\packageManager\scans\scapOpenCklClosed.tpl]] 
				</div>
			</div>
		</div>
	</div>
</div>

<script>
	csts.onLoad(function(){
		csts.setHeader("Package Manager - <span id='package'>{{package}}</span> - Scan Summary");
		jQuery('[data-toggle="tooltip"]').tooltip();
		jQuery('#myTabs a').click(function (e) { e.preventDefault();  jQuery(this).tab('show')});
	});
</script>	