<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="viewport" content="width=device-width, initial-scale=1">
<!-- The above 3 meta tags *must* come first in the head; any other head content must come *after* these tags -->
<meta name="description" content="">
<meta name="author" content="">

<!-- Bootstrap core CSS -->
<link href="{{pwd}}\wwwroot\assets\css\bootstrap.css" rel="stylesheet">

<!-- Custom styles for this template -->
<link href="{{pwd}}\wwwroot\assets\css\dashboard.css" rel="stylesheet">
<link href="{{pwd}}\wwwroot\assets\css\bootstrap-sortable.css" rel="stylesheet">
<link href="{{pwd}}\wwwroot\assets\css\bootstrap-treeview.min.css" rel="stylesheet">
<link href="{{pwd}}\wwwroot\assets\css\bootstrap-switch.min.css" rel="stylesheet">
<script>var client = {};</script>
<script src="{{pwd}}\wwwroot\assets\js\csts.js"></script>
</head>
<body>
<nav class="navbar navbar-inverse navbar-fixed-top">
<div class="container-fluid">
<div class="navbar-header">
<a class="navbar-brand" href="#">Package Manager </a>
</div>
<div id="navbar" class="navbar-collapse collapse">
<ul class="nav navbar-nav navbar-right">
<li><a href="#" data-toggle="modal" data-target="#mySettingsModal" >Settings&nbsp;</a></li>
<li><a href="#" onclick="saveMe()">Save&nbsp;</a></li>
<li><a href="#">Help&nbsp;&nbsp;&nbsp;&nbsp;</a></li>
</ul>
</div>
</div>
</nav>
<div class="container-fluid">
<div class="row" id="mainContent">
{{mainContent}}
</div>
</div>
<div id="exportRaw" rows="10" cols="100"></div>

<!-- Settings Modal -->
<div class="modal fade" id="mySettingsModal" tabindex="-1" role="dialog" aria-labelledby="mySettingsModalLabel">
	<div class="modal-dialog" role="document">
		<div class="modal-content">
			<div class="modal-header">
				<button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
				<h4 class="modal-title" id="myModalLabel">Settings</h4>
			</div>
			<div class="modal-body">
				
				<div class="panel-group" id="accordion" role="tablist" aria-multiselectable="true">
					<div class="panel panel-default">
						<div class="panel-heading" role="tab" id="headingOne">
							<h4 class="panel-title">
								<a role="button" data-toggle="collapse" data-parent="#accordion" href="#collapseOne" aria-expanded="true" aria-controls="collapseOne">
									STIGs
								</a>
							</h4>
						</div>
						<div id="collapseOne" class="panel-collapse collapse in" role="tabpanel" aria-labelledby="headingOne">
							<div class="panel-body">
								<div class="table-responsive">
									$( $package = ([xml](gc (ls .\packages\*\package.xml | select -first 1))) )
									<table class="table table-striped table-bordered">
										<thead>
										<tr>
											<th>Type</th>
											<th>Count</th>
											<th>Oldest</th>
											<th>Newest</th>
										</tr>
										</thead>
										<tbody>
											<tr>
												<td>STIGs</th>
												<td>$( $package.cstsPackage.settings.stigs.manual.count)</td>
												<td>$( ([datetime]($package.cstsPackage.settings.stigs.manual | sort { [datetime]$($_.date) } | select -first 1 -expand date)).ToString("yyyy-MM-dd") )</td>
												<td>$( ([datetime]($package.cstsPackage.settings.stigs.manual | sort { [datetime]$($_.date) } -Descending | select -first 1 -expand date)).ToString("yyyy-MM-dd") )</td>
											</tr>
											<tr>
												<td>Benchmarks</th>
												<td>$( $package.cstsPackage.settings.stigs.benchmark.count)</td>
												<td>$( ([datetime]($package.cstsPackage.settings.stigs.benchmark | sort { [datetime]$($_.date) } | select -first 1 -expand date)).ToString("yyyy-MM-dd") )</td>
												<td>$( ([datetime]($package.cstsPackage.settings.stigs.benchmark | sort { [datetime]$($_.date) } -Descending | select -first 1 -expand date)).ToString("yyyy-MM-dd") )</td>
											</tr>
										</tbody>
									</table>
								</div>
								
								<button class="btn btn-primary capture-me" id="settings-scan-stigs">
									Rescan/Update STIGs
								</button>
									
							</div>
						</div>
					</div>
						
					<div class="panel panel-default">
						<div class="panel-heading" role="tab" id="headingTwo">
							<h4 class="panel-title">
								<a class="collapsed" role="button" data-toggle="collapse" data-parent="#accordion" href="#collapseTwo" aria-expanded="false" aria-controls="collapseTwo">
									Collapsible Group Item #2
								</a>
							</h4>
						</div>
						<div id="collapseTwo" class="panel-collapse collapse" role="tabpanel" aria-labelledby="headingTwo">
							<div class="panel-body">
								Anim pariatur cliche reprehenderit, enim eiusmod high life accusamus terry richardson ad squid. 3 wolf moon officia aute, non cupidatat skateboard dolor brunch. Food truck quinoa nesciunt laborum eiusmod. Brunch 3 wolf moon tempor, sunt aliqua put a bird on it squid single-origin coffee nulla assumenda shoreditch et. Nihil anim keffiyeh helvetica, craft beer labore wes anderson cred nesciunt sapiente ea proident. Ad vegan excepteur butcher vice lomo. Leggings occaecat craft beer farm-to-table, raw denim aesthetic synth nesciunt you probably haven't heard of them accusamus labore sustainable VHS.
							</div>
						</div>
					</div>
				</div>
	
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
				<button type="button" class="btn btn-primary" id="settings_submit" data-dismiss="modal" >Save</button>
			</div>
		</div>
	</div>
</div>


<script>

function saveMe(){
	jQuery(".exportable").each(function(){
		jQuery('#exportRaw').html( "<table>" + jQuery(this).html() + "</table>" );
		jQuery("#exportRaw table input").remove();
		jQuery("#exportRaw a").replaceWith(function(){
			return (jQuery(this).html());
		});
		
		exportData('text/xml', jQuery('#exportRaw').html() , jQuery('div.navbar-header a.navbar-brand').text() + '_' + moment().format('YYYYMMDD_HHmmss') +  '.doc' );
	});
}

function exportData(mime, content, filename){
	var blob = new Blob([content], { type: mime + ';charset=utf-8;' });
	if (navigator.msSaveBlob) {
		navigator.msSaveBlob(blob, filename);
	} else {
		var link = document.createElement("a");
		if (link.download !== undefined) {
			
			var url = URL.createObjectURL(blob);
			link.setAttribute("href", url);
			link.setAttribute("download", filename);
			link.style.visibility = 'hidden';
			document.body.appendChild(link);
			link.click();
			document.body.removeChild(link);
		}
	}
}

</script>

<script src="{{pwd}}\wwwroot\assets\js\jquery-1.12.0.min.js"></script>
<script src="{{pwd}}\wwwroot\assets\js\bootstrap.min.js"></script>
<script src="{{pwd}}\wwwroot\assets\js\bootstrap-sortable.js"></script>
<script src="{{pwd}}\wwwroot\assets\js\moment.min.js"></script>
<script src="{{pwd}}\wwwroot\assets\js\bootstrap-treeview.min.js"></script>
<script src="{{pwd}}\wwwroot\assets\js\bootstrap-switch.min.js"></script>




</body>
</html>