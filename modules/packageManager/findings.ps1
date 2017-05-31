method -private showFindings{
	$webVars = @{}
	$private.showWait();
	
	$webVars['pwd'] = $pwd
	$webVars['package'] =  $private.package.toUpper()
	
	$webVars['acasFindings'] = $private.findings.selectNodes("//cstsPackage/findings/acas/finding[rawRisk!='None']") | sort { $_.rawRisk, $_.riskStatement }
	$webVars['scapFindings'] = $private.findings.selectNodes("//cstsPackage/findings/scap/finding") 
	$webVars['cklFindings'] = $private.findings.selectNodes("//cstsPackage/findings/ckl/finding") | sort { $_.rawRisk, $_.riskStatement }
	
	$webVars['mainContent'] = gc "$($pwd)\wwwroot\views\packageManager\findings.tpl"
	$html = $private.renderTpl("packageManagerDefault.tpl", $webVars)
	$private.displayHtml( $html  )
}