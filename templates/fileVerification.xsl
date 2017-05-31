<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:cdf="http://checklists.nist.gov/xccdf/1.1" >
	
	<xsl:param name="reportScans"></xsl:param>
	
	<xsl:template match="/">
		<html>
			<head>
				<title>
				    File Verification Report
				</title>
				<script>

					function actSelScan(scan){
						var divs = document.getElementsByClassName('scanFiles');
						for(var i = 0; i &lt; divs.length; i++) {
							document.getElementById( divs[i].id ).style.display = 'none';
							
						}
						
						var tabs = document.getElementsByClassName('fileTable');
						for(var i = 0; i &lt; tabs.length; i++) {
							sortedTable( tabs[i] );	
						}
						
						document.getElementById( 'reportBody' ).style.display = 'block';

						['','tblOriginalMatches', 'tblRecentMatches', 'tblKnownMatches', 'tblOriginalMismatches', 'tblRecentMismatches', 'tblKnownMismatches', 'tblOriginalExtras', 'tblRecentExtras', 'tblKnownExtras', 'tblOriginalMissing', 'tblRecentMissing', 'tblKnownMissing', 'tblSummary'].forEach(function(name){
							if(document.getElementById( name + scan ) ){
								document.getElementById( name + scan ).style.display = 'block';
							}
						})
						
						
						for(var i = 0; i &lt; divs.length; i++) {
							
							if ( document.getElementById( divs[i].id ).getElementsByTagName("table")[0].rows.length &lt; 2){
								document.getElementById( divs[i].id ).style.display = 'none';
							}
						}

					}
					
					function isNumeric(n) {
						return !isNaN(parseFloat(n)) &amp;&amp; isFinite(n);
					}
					
					function sortedTable(table) {

						table.lastColumn = -1;
						table.onclick = function(ev) {
							if (ev.target.nodeName == 'TH') {
								var row = ev.target.parentNode;
								for (var j=0;j&lt;row.cells.length;j++) {
									if (row.cells[j] == ev.target) {

										if(row.cells[j].textContent.substr( row.cells[j].textContent.length - 3) == '(v)'){
											row.cells[j].textContent = row.cells[j].textContent.replace("(v)","(^)") ;
										}else if(row.cells[j].textContent.substr( row.cells[j].textContent.length - 3) == '(^)'){
											row.cells[j].textContent = row.cells[j].textContent.replace("(^)","(v)") ;
										}else{
											row.cells[j].textContent += "(^)";
										}
										
										var rows = [];
										for (var i=1;i&lt;table.rows.length;i++) {
											rows.push(table.rows[i]);
										}
										
										if (j == table.lastColumn) {
											rows.reverse();
										} else {
											rows.sort(function(a,b) { 
												if(isNumeric(a.cells[j].textContent)){
													switch(true){
														case parseFloat(a.cells[j].textContent) &gt; parseFloat(b.cells[j].textContent) : 
															return 1;
															break;
														case parseFloat(a.cells[j].textContent) &lt; parseFloat(b.cells[j].textContent) : 
															return -1;
															break;
														default :
															return 0;
															break;
													}
												}else{
													return a.cells[j].textContent.localeCompare(b.cells[j].textContent) 
												}
											});
										}
										table.lastColumn = j;
										for (var i=0;i&lt;rows.length;i++) {
											table.appendChild(rows[i]);
										}
										break;
									}else{
										row.cells[j].textContent = row.cells[j].textContent.replace("(^)","") ;
										row.cells[j].textContent = row.cells[j].textContent.replace("(v)","") ;
									}
								}
							}
							return true;
						};
					}			
					
				</script>
				<style>
					body{
						font-family: arial;
						font-size: .6em;
						background-color:#eee;
						margin: 0;
					}
					h1{
						color: #40505e;
						font-size:3em;
						text-align:center;
					}
					h2{
						color: #40505e;
						font-size:2em;
						margin-top:25px;
						margin-bottom:0px;
					}
					h3{
						color: #40505e;
						font-size:1.8em;
						margin-top:0px;
						margin-bottom:0px;
					}
					.reportHeader{
						width:90%;
						margin-left:auto;
						margin-right:auto;
						margin-bottom:0px;
						text-align:left;
						border-bottom:1px solid #40505e;
						border-left:1px solid #40505e;
						border-right:1px solid #40505e;
						font-size:1.4em;
						padding:8px;
						background-color: #fff;
					}
					#reportBody{
					    background: #fff;
						width: 90%;
						margin-left: auto;
						margin-right: auto;
						margin-top: 0px;
						text-align:left;
						font-size:1.4em;
						padding:8px;
						display:none;
						border-bottom:1px solid #40505e;
						border-left:1px solid #40505e;
						border-right:1px solid #40505e;
					}
					.scanFiles{
						width: 95%;
						margin-left:auto;
						margin-right:auto;
					}
					.fileTable{
						border:2px solid #EEEFF0;
						border-collapse: collapse;
						width:100%;
						margin-top:5px;
					}
					.fileTable th{
						background:#00a5b5;
						color:#fff;
						border:1px solid #EEEFF0;	
						padding-top:5px;
						padding-bottom: 5px;
						text-decoration: underline;
						cursor:pointer;
					}
					.fileTable td{
						border:0px;	
						font-size: .8em;
					}
					.fileTable tr:nth-child(odd) {
						background: #EEEFF0
					}
					table.fileTable tr:hover td {
						background-color: #ddf;
					}

					.hash{
						font-family: monospace;
						font-size: 1em !important;
					}
					.fileSize{
						font-family: monospace;
						color: #6b7ecb;
						text-align: center;
						font-size: 1em !important;
					}
					.green{
						color: #64ae5d;
					}
					.blue{
						color: #497ecf;
					}
					.orange{
						color: #eb851d;
					}
					.red{
						color: #c61113;
					}
				</style>
			</head>
			<body>
				<div class="reportHeader">
					
					<h1>File Integrity Report</h1>
					
					
					Select the scan to review:
					
					<select id="cboScans" onChange="actSelScan(this.value);">
						<option />
						<xsl:apply-templates select="fileVerificationReport/scan" mode="dropDownBox">
							<xsl:sort select="@TimeStamp" order="descending"/>
						</xsl:apply-templates>
					</select>
					
					
					
					
				</div>
				<div id="reportBody">				
					<xsl:apply-templates select="fileVerificationReport/scan" mode="showSummary">
						<xsl:sort select="@TimeStamp" order="descending"/> 
					</xsl:apply-templates>
					
					<xsl:apply-templates select="fileVerificationReport/scan" mode="showOriginalMissing">
						<xsl:sort select="@TimeStamp" order="descending"/>
					</xsl:apply-templates>
					
					<xsl:apply-templates select="fileVerificationReport/scan" mode="showRecentMissing">
						<xsl:sort select="@TimeStamp" order="descending"/>
					</xsl:apply-templates>
					
					<xsl:apply-templates select="fileVerificationReport/scan" mode="showKnownMissing">
						<xsl:sort select="@TimeStamp" order="descending"/>
					</xsl:apply-templates>
					
					<xsl:apply-templates select="fileVerificationReport/scan" mode="showOriginalExtras">
						<xsl:sort select="@TimeStamp" order="descending"/>
					</xsl:apply-templates>
					
					<xsl:apply-templates select="fileVerificationReport/scan" mode="showRecentExtras">
						<xsl:sort select="@TimeStamp" order="descending"/>
					</xsl:apply-templates>
					
					<xsl:apply-templates select="fileVerificationReport/scan" mode="showKnownExtras">
						<xsl:sort select="@TimeStamp" order="descending"/>
					</xsl:apply-templates>
					
					<xsl:apply-templates select="fileVerificationReport/scan" mode="showOriginalMismatches">
						<xsl:sort select="@TimeStamp" order="descending"/>
					</xsl:apply-templates>
					
					<xsl:apply-templates select="fileVerificationReport/scan" mode="showRecentMismatches">
						<xsl:sort select="@TimeStamp" order="descending"/>
					</xsl:apply-templates>
					
					<xsl:apply-templates select="fileVerificationReport/scan" mode="showKnownMismatches">
						<xsl:sort select="@TimeStamp" order="descending"/>
					</xsl:apply-templates>
					
					<xsl:apply-templates select="fileVerificationReport/scan" mode="showOriginalMatches">
						<xsl:sort select="@TimeStamp" order="descending"/>
					</xsl:apply-templates>
					
					<xsl:apply-templates select="fileVerificationReport/scan" mode="showRecentMatches">
						<xsl:sort select="@TimeStamp" order="descending"/>
					</xsl:apply-templates>
					
					<xsl:apply-templates select="fileVerificationReport/scan" mode="showKnownMatches">
						<xsl:sort select="@TimeStamp" order="descending"/>
					</xsl:apply-templates>
					
					<xsl:apply-templates select="fileVerificationReport/scan" mode="showFiles">
						<xsl:sort select="@TimeStamp" order="descending"/>
					</xsl:apply-templates>
				</div>
			</body>
		</html>
	</xsl:template>
	
	<xsl:template match="fileVerificationReport/scan" mode="dropDownBox">
		<xsl:if test="not(position() > $reportScans) or position() = last()">
			<option><xsl:value-of select="@checkFolder" /> - <xsl:value-of select="@TimeStamp" /></option>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="scan" mode="showSummary">
		
		
		<xsl:if test="not(position() > $reportScans) or position() = last()">
		
			<div  style="display:none;" class="scanFiles">
			<xsl:attribute name="id">tblSummary<xsl:value-of select="@checkFolder"/> - <xsl:value-of select="@TimeStamp"/></xsl:attribute>
			<h2>Scan Summary</h2>
			<h3>Folder: <xsl:value-of select="@checkFolder"/></h3>
			<h3>Scan Time: <xsl:value-of select="@TimeStamp"/></h3>
			<h3>Hash Algorithm: <xsl:value-of select="@hashAlgorithm"/></h3>
			<table class="fileTable">
				
				<tr>
					<th>Rule Name</th>
					<th>No Change</th>
					<th>Added</th>
					<th>Removed</th>
					<th>Modified</th>
				</tr>
				<tr>
					<td>File Integrity against Original Check-in</td>
					<td class="green"><xsl:value-of select="count(matches/original/file)" /></td>
					<td class="blue"><xsl:value-of select="count(extras/original/file)" /></td>
					<td class="orange"><xsl:value-of select="count(missing/original/file)" /></td>
					<td class="red"><xsl:value-of select="count(mismatches/original/file)" /></td>
				</tr>
				<tr>
					<td>File Integrity against Previous Scan</td>
					<td class="green"><xsl:value-of select="count(matches/recent/file)" /></td>
					<td class="blue"><xsl:value-of select="count(extras/recent/file)" /></td>
					<td class="orange"><xsl:value-of select="count(missing/recent/file)" /></td>
					<td class="red"><xsl:value-of select="count(mismatches/recent/file)" /></td>
				</tr>
				<tr>
					<td>File Integrity against Known Good Folder</td>
					<td class="green"><xsl:value-of select="count(matches/known/file)" /></td>
					<td class="blue"><xsl:value-of select="count(extras/known/file)" /></td>
					<td class="orange"><xsl:value-of select="count(missing/known/file)" /></td>
					<td class="red"><xsl:value-of select="count(mismatches/known/file)" /></td>
				</tr>
				
			</table>
			</div>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="scan" mode="showOriginalMissing">
		
		
		<xsl:if test="not(position() > $reportScans) or position() = last()">

			<div  style="display:none;" class="scanFiles">
				<xsl:attribute name="id">tblOriginalMissing<xsl:value-of select="@checkFolder"/> - <xsl:value-of select="@TimeStamp"/></xsl:attribute>
				<h2>Files from Original Scan that are Missing in the Current Scan</h2>
				<table class="fileTable">
					
					<tr>
						<th>File Name</th>
						<th>Original File Hash (<xsl:value-of select="@hashAlgorithm" />)</th>
					</tr>
					<xsl:for-each select="missing/original/file">
						<tr>
							<td>
								<xsl:value-of select="./@path" />
							</td>
							<td class="hash green">
								<xsl:value-of select="./@originalHash" />
							</td>
						</tr>
					</xsl:for-each>
				</table>
			</div>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="scan" mode="showFiles">
		
		
		<xsl:if test="not(position() > $reportScans) or position() = last()">
			<div  style="display:none;" class="scanFiles">
				<xsl:attribute name="id"><xsl:value-of select="@checkFolder"/> - <xsl:value-of select="@TimeStamp"/></xsl:attribute>
				<h2>Files Found in Current Scan</h2>
				<table class="fileTable">
					
					<tr>
						<th>File Name</th>
						<th>Hash</th>
						<th>File Size</th>
						<th>Created</th>
						<th>Accessed</th>
						<th>Modified</th>
					</tr>
					<xsl:for-each select="files/file">
						<tr>
							<td>
								<xsl:value-of select="./@path" />
							</td>
							<td class="hash green">
								<xsl:value-of select="./@hash" />
							</td>
							<td class="fileSize blue">
								<xsl:value-of select="./@length" />
							</td>
							<td>
								<xsl:value-of select="./@created" />
							</td>
							<td>
								<xsl:value-of select="./@accessed" />
							</td>
							<td>
								<xsl:value-of select="./@modified" />
							</td>
						</tr>
					</xsl:for-each>
				</table>
			</div>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="scan" mode="showRecentMissing">
		
		
		<xsl:if test="not(position() > $reportScans) or position() = last()">
			<div  style="display:none;" class="scanFiles">
				<xsl:attribute name="id">tblRecentMissing<xsl:value-of select="@checkFolder"/> - <xsl:value-of select="@TimeStamp"/></xsl:attribute>
				<h2>Files From The Most Recent Scan That Are Missing From The Current Scan</h2>
				<table class="fileTable">
					
					<tr>
						<th>File Name</th>
						<th>Recent Scan File Hash (<xsl:value-of select="@hashAlgorithm" />)</th>
					</tr>
					<xsl:for-each select="missing/recent/file">
						<tr>
							<td>
								<xsl:value-of select="./@path" />
							</td>
							<td class="hash green">
								<xsl:value-of select="./@recentHash" />
							</td>
						</tr>
					</xsl:for-each>
				</table>
			</div>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="scan" mode="showKnownMissing">
		
		
		<xsl:if test="not(position() > $reportScans) or position() = last()">
		
		<div  style="display:none;" class="scanFiles">
		<xsl:attribute name="id">tblKnownMissing<xsl:value-of select="@checkFolder"/> - <xsl:value-of select="@TimeStamp"/></xsl:attribute>
		<h2>Files From The Known Good Folder That Are Missing From The Current Scan</h2>
		<table class="fileTable">
			
			<tr>
				<th>File Name</th>
				<th>Hash</th>
				<th>File Size</th>
				<th>Created</th>
				<th>Accessed</th>
				<th>Modified</th>
			</tr>
			<xsl:for-each select="missing/known/file">
				<tr>
					<td>
						<xsl:value-of select="./@path" />
					</td>
					<td class="hash green">
						<xsl:value-of select="./@knownHash" />
					</td>
					<td class="fileSize blue">
						<xsl:value-of select="./@length" />
					</td>
					<td>
						<xsl:value-of select="./@created" />
					</td>
					<td>
						<xsl:value-of select="./@accessed" />
					</td>
					<td>
						<xsl:value-of select="./@modified" />
					</td>
				</tr>
			</xsl:for-each>
		</table>
		</div>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="scan" mode="showOriginalMatches">
		
		
		<xsl:if test="not(position() > $reportScans) or position() = last()">
		
		<div  style="display:none;" class="scanFiles">
		<xsl:attribute name="id">tblOriginalMatches<xsl:value-of select="@checkFolder"/> - <xsl:value-of select="@TimeStamp"/></xsl:attribute>
		<h2>Original Scan Matches</h2>
		<table class="fileTable">
			
			<tr>
				<th>File Name</th>
			</tr>
			<xsl:for-each select="matches/original/file">
				<tr>
					<td>
						<xsl:value-of select="./@path" />
					</td>
				</tr>
			</xsl:for-each>
		</table>
		</div>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="scan" mode="showRecentMatches">
		
		
		<xsl:if test="not(position() > $reportScans) or position() = last()">
		
		<div  style="display:none;" class="scanFiles">
		<xsl:attribute name="id">tblRecentMatches<xsl:value-of select="@checkFolder"/> - <xsl:value-of select="@TimeStamp"/></xsl:attribute>
		<h2>Recent Scan Matches</h2>
		<table class="fileTable">
			
			<tr>
				<th>File Name</th>
			</tr>
			<xsl:for-each select="matches/recent/file">
				<tr>
					<td>
						<xsl:value-of select="./@path" />
					</td>
				</tr>
			</xsl:for-each>
		</table>
		</div>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="scan" mode="showKnownMatches">
		
		
		<xsl:if test="not(position() > $reportScans) or position() = last()">
		
		<div  style="display:none;" class="scanFiles">
		<xsl:attribute name="id">tblKnownMatches<xsl:value-of select="@checkFolder"/> - <xsl:value-of select="@TimeStamp"/></xsl:attribute>
		<h2>Known Good Folder Matches</h2>
		<table class="fileTable">
			
			<tr>
				<th>File Name</th>
			</tr>
			<xsl:for-each select="matches/known/file">
				<tr>
					<td>
						<xsl:value-of select="./@path" />
					</td>
				</tr>
			</xsl:for-each>
		</table>
		</div>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="scan" mode="showOriginalMismatches">
		
		
		<xsl:if test="not(position() > $reportScans) or position() = last()">
		
		<div  style="display:none;" class="scanFiles">
		<xsl:attribute name="id">tblOriginalMismatches<xsl:value-of select="@checkFolder"/> - <xsl:value-of select="@TimeStamp"/></xsl:attribute>
		<h2>Files that don&apos;t match the Original Scan</h2>
		<table class="fileTable">
			
			<tr>
				<th>File Name</th>
				<th>Hash</th>
				<th>File Size</th>
				<th>Created</th>
				<th>Accessed</th>
				<th>Modified</th>
			</tr>
			<xsl:for-each select="mismatches/original/file">
				<tr>
					<td>
						<xsl:value-of select="./@path" />
					</td>
					<td class="hash green">
						<xsl:value-of select="./@scanHash" />
					</td>
					<td class="fileSize blue">
						<xsl:value-of select="./@length" />
					</td>
					<td>
						<xsl:value-of select="./@created" />
					</td>
					<td>
						<xsl:value-of select="./@accessed" />
					</td>
					<td>
						<xsl:value-of select="./@modified" />
					</td>
				</tr>
			</xsl:for-each>
		</table>
		</div>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="scan" mode="showRecentMismatches">
		
		
		<xsl:if test="not(position() > $reportScans) or position() = last()">
		<div  style="display:none;" class="scanFiles">
		<xsl:attribute name="id">tblRecentMismatches<xsl:value-of select="@checkFolder"/> - <xsl:value-of select="@TimeStamp"/></xsl:attribute>
		<h2>Files that don&apos;t match the most Recent Scan</h2>
		<table class="fileTable">
			
			<tr>
				<th>File Name</th>
				<th>Hash</th>
				<th>File Size</th>
				<th>Created</th>
				<th>Accessed</th>
				<th>Modified</th>
			</tr>
			<xsl:for-each select="mismatches/recent/file">
				<tr>
					<td>
						<xsl:value-of select="./@path" />
					</td>
					<td class="hash green">
						<xsl:value-of select="./@scanHash" />
					</td>
					<td class="fileSize blue">
						<xsl:value-of select="./@length" />
					</td>
					<td>
						<xsl:value-of select="./@created" />
					</td>
					<td>
						<xsl:value-of select="./@accessed" />
					</td>
					<td>
						<xsl:value-of select="./@modified" />
					</td>
				</tr>
			</xsl:for-each>
		</table>
		</div>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="scan" mode="showKnownMismatches">
		
		
		<xsl:if test="not(position() > $reportScans) or position() = last()">
		
		<div  style="display:none;" class="scanFiles">
		<xsl:attribute name="id">tblKnownMismatches<xsl:value-of select="@checkFolder"/> - <xsl:value-of select="@TimeStamp"/></xsl:attribute>
		<h2>Files that don&apos;t match the Known Good Folder</h2>
		<table class="fileTable">
			
			<tr>
				<th>File Name</th>
				<th>Hash</th>
				<th>File Size</th>
				<th>Created</th>
				<th>Accessed</th>
				<th>Modified</th>
			</tr>
			<xsl:for-each select="mismatches/known/file">
				<tr>
					<td>
						<xsl:value-of select="./@path" />
					</td>
					<td class="hash green">
						<xsl:value-of select="./@knownHash" />
					</td>
					<td class="fileSize blue">
						<xsl:value-of select="./@length" />
					</td>
					<td>
						<xsl:value-of select="./@created" />
					</td>
					<td>
						<xsl:value-of select="./@accessed" />
					</td>
					<td>
						<xsl:value-of select="./@modified" />
					</td>
				</tr>
			</xsl:for-each>
		</table>
		</div>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="scan" mode="showOriginalExtras">
		
		
		<xsl:if test="not(position() > $reportScans) or position() = last()">
		
		<div  style="display:none;" class="scanFiles">
		<xsl:attribute name="id">tblOriginalExtras<xsl:value-of select="@checkFolder"/> - <xsl:value-of select="@TimeStamp"/></xsl:attribute>
		<h2>Files From The Current Scan That Aren&apos;t In The Original Scan</h2>
		<table class="fileTable">
			
			<tr>
				<th>File Name</th>
				<th>Hash</th>
				<th>File Size</th>
				<th>Created</th>
				<th>Accessed</th>
				<th>Modified</th>
			</tr>
			<xsl:for-each select="extras/original/file">
				<tr>
					<td>
						<xsl:value-of select="./@path" />
					</td>
					<td class="hash green">
						<xsl:value-of select="./@scanHash" />
					</td>
					<td class="fileSize blue">
						<xsl:value-of select="./@length" />
					</td>
					<td>
						<xsl:value-of select="./@created" />
					</td>
					<td>
						<xsl:value-of select="./@accessed" />
					</td>
					<td>
						<xsl:value-of select="./@modified" />
					</td>
				</tr>
			</xsl:for-each>
		</table>
		</div>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="scan" mode="showRecentExtras">
		
		
		<xsl:if test="not(position() > $reportScans) or position() = last()">
		
		<div  style="display:none;" class="scanFiles">
		<xsl:attribute name="id">tblRecentExtras<xsl:value-of select="@checkFolder"/> - <xsl:value-of select="@TimeStamp"/></xsl:attribute>
		<h2>Files From The Current Scan That Aren&apos;t In The Most Recent Scan</h2>
		<table class="fileTable">
			
			<tr>
				<th>File Name</th>
				<th>Hash</th>
				<th>File Size</th>
				<th>Created</th>
				<th>Accessed</th>
				<th>Modified</th>
			</tr>
			<xsl:for-each select="extras/recent/file">
				<tr>
					<td>
						<xsl:value-of select="./@path" />
					</td>
					<td class="hash green">
						<xsl:value-of select="./@scanHash" />
					</td>
					<td class="fileSize blue">
						<xsl:value-of select="./@length" />
					</td>
					<td>
						<xsl:value-of select="./@created" />
					</td>
					<td>
						<xsl:value-of select="./@accessed" />
					</td>
					<td>
						<xsl:value-of select="./@modified" />
					</td>
				</tr>
			</xsl:for-each>
		</table>
		</div>
		</xsl:if>
	</xsl:template>
	<xsl:template match="scan" mode="showKnownExtras">
		
		
		<xsl:if test="not(position() > $reportScans) or position() = last()">
		
		<div  style="display:none;" class="scanFiles">
		<xsl:attribute name="id">tblKnownExtras<xsl:value-of select="@checkFolder"/> - <xsl:value-of select="@TimeStamp"/></xsl:attribute>
		<h2>Files From The Current Scan That Aren&apos;t In The Known Good Folder</h2>
		<table class="fileTable">
			
			<tr>
				<th>File Name</th>
				<th>Hash</th>
				<th>File Size</th>
				<th>Created</th>
				<th>Accessed</th>
				<th>Modified</th>
			</tr>
			<xsl:for-each select="extras/known/file">
				<tr>
					<td>
						<xsl:value-of select="./@path" />
					</td>
					<td class="hash green">
						<xsl:value-of select="./@scanHash" />
					</td>
					<td class="fileSize blue">
						<xsl:value-of select="./@length" />
					</td>
					<td>
						<xsl:value-of select="./@created" />
					</td>
					<td>
						<xsl:value-of select="./@accessed" />
					</td>
					<td>
						<xsl:value-of select="./@modified" />
					</td>
				</tr>
			</xsl:for-each>
		</table>
		</div>
		</xsl:if>
	</xsl:template>
</xsl:stylesheet>