<h1 class="page-header">Requirements</h1>
<div class="col-sm-12 col-md-12 main">
	<div class="table-responsive">
		<div class="panel panel-default">
			<div class="panel-heading">
				<div class="row">
					<div class="col-md-6">
						<h3 class="panel-title">Requirements</h3>
					</div>
					<div class="col-md-6">
						<button class="btn btn-primary btn-xs pull-right" id="requirements-commit-updates">Commit Updates</button>
					</div>
				</div>
			</div>
			<div class="panel-body">
				[[wwwroot\views\packageManager\requirements\tabList.tpl]] 
				<div class="tab-content" id="myTabContent" style="min-height:400px;">
					[[wwwroot\views\packageManager\requirements\summary.tpl]] 
					[[wwwroot\views\packageManager\requirements\acas.tpl]] 
					[[wwwroot\views\packageManager\requirements\ckl.tpl]] 
					[[wwwroot\views\packageManager\requirements\scap.tpl]] 
				</div>
			</div>
		</div>
	</div>
</div>


<script>
	csts.onLoad( function(){
		csts.setHeader("Package Manager - <span id='package'>{{package}}</span> - Requirements");
		jQuery('[data-toggle="tooltip"]').tooltip();
		jQuery('#myTabs a').click(function (e) { e.preventDefault();  jQuery(this).tab('show')});
		jQuery('#req-summary-tab').click();
	});
</script>	