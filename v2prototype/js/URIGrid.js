function URIGrid(uriList, view, selectedColumn, sortOrder)
{
	URIGrid.SORT_ASCENDING = 0;
	URIGrid.SORT_DESCENDING = 1;
	URIGrid.ASCENDING_GLYPH = String.fromCharCode(9650);
	URIGrid.DESCENDING_GLYPH = String.fromCharCode(9660);
	URIGrid.DELETE_GLYPH = String.fromCharCode(8864);
	URIGrid.GRAPH_GLYPH = String.fromCharCode(9680);
	URIGrid.SPACE_GLYPH = String.fromCharCode(8192);
	this.glyphs = [URIGrid.ASCENDING_GLYPH, URIGrid.DESCENDING_GLYPH];
	this.name = "URIGrid";
	this.sortOrder = sortOrder;
	this.selectedColumn = selectedColumn;
	this.listeners = [];
	this.data = uriList;
	this.obj = this;
	this.floater = document.createElement("div");
	var id = document.createAttribute("id");
	id.value = "floater";
	this.floater.setAttributeNode(id);
    this.floater.style.visibility = "hidden";
	this.html = this.getHTMLFromList(uriList,view);
	this.tempRowLimit = 20;
}
URIGrid.prototype.addListener = function (callback)
{
		this.listeners.push(callback);
}
URIGrid.prototype.redraw = function (uriList, view)
{
	this.html = this.getHTMLFromList(uriList,view);
}
URIGrid.prototype.getHTMLFromList = function (uriList, view)
{
	var tempList = [];
	var div = document.createElement("div");
	var table = document.createElement("table");
	var header = this.createColumnHeaderFields(uriList[0], view);
	table.appendChild(header);

	for (var i=0;i<uriList.length;i++)
	//for (var i=0;i<this.tempRowLimit;i++)
	{
		var tr = document.createElement("tr");
		var id = document.createAttribute("id");
		id.value="field";
		tr.setAttributeNode(id);
		for (var j=0;j<view.length;j++)
		{
			for (var k=0;k<view.length;k++)
			{
				var td = this.createFieldsFromRow(uriList[i], view, j);
			}
			tr.appendChild(td);
		}
		table.appendChild(tr);
	}
	div.appendChild(this.floater);
	div.appendChild(table);
	return div;
}
URIGrid.prototype.createColumnHeaderFields = function(row, view)
{
	var o = row;
	var tr = document.createElement("tr");
	var id = document.createAttribute("id");
	id.value="column_header";
	tr.setAttributeNode(id);

	for (var i=0;i<view.length;i++)
	{
		var td= document.createElement("td");
		var a = document.createElement("a");
		a.href="#";
		a.obj = this;
		a.onclick = this.onColumnSelect;
		var id = document.createAttribute("id");
		id.value=view[i];
		a.setAttributeNode(id);
		var label = document.createTextNode(view[i]);
		a.appendChild(label);
		td.appendChild(a);	

		var delete_icon = document.createElement("a");
		delete_icon.href="#";
		delete_icon.onclick = this.onIconClick.bind(this);
		var delete_id = document.createAttribute("id");
		delete_id.value = "delete";
		delete_icon.setAttributeNode(delete_id);

		var delete_field = document.createAttribute("field");
		delete_field.value=view[i];
		delete_icon.setAttributeNode(delete_field);

		var chart_icon = document.createElement("a");
		chart_icon.href="#";
		chart_icon.onclick = this.onIconClick.bind(this);
		var chart_id = document.createAttribute("id");
		chart_id.value = "chart";
		chart_icon.setAttributeNode(chart_id);
		var chart_field = document.createAttribute("field");
		chart_field.value=view[i];
		chart_icon.setAttributeNode(chart_field);

		var glyph_text;
		var delete_icon_text;
		var chart_icon_text;

		if (view[i] == this.selectedColumn)
		{
			glyph_text = document.createTextNode(URIGrid.SPACE_GLYPH + this.glyphs[this.sortOrder] + URIGrid.SPACE_GLYPH);
			delete_icon_text = document.createTextNode(URIGrid.DELETE_GLYPH);
			chart_icon_text = document.createTextNode(URIGrid.GRAPH_GLYPH);
			delete_icon.appendChild(delete_icon_text);
			chart_icon.appendChild(chart_icon_text);

			td.appendChild(glyph_text);
			td.appendChild(delete_icon);
			td.appendChild(chart_icon);
		} 
		tr.appendChild(td);
	}
	return tr;
}
URIGrid.prototype.createFieldsFromRow = function(row,view,index)
{
	var o = row;
	for (var i=0;i<view.length;i++)
	{
		var td= document.createElement("td");
		var a = document.createElement("a");
		//a.href="#";
		a.obj = this;
		a.onclick = this.onClick;
		a.onmouseover = this.onMouseOver;

		var id = document.createAttribute("id");
		id.value=view[index];
		a.setAttributeNode(id);

		var label = document.createTextNode(eval ("o." + view[index]));
		a.appendChild(label);
		td.appendChild(a);	
	}
	return td;
}
URIGrid.prototype.setSelectedColumn = function (field)
{
	this.selectedColumn = field;
}
URIGrid.prototype.setSortOrder = function (order)
{
	this.sortOrder = order;
}

URIGrid.prototype.onColumnSelect = function (e)
{
	// for now
	var o = {};
	o.target = e.target;
	o.field = e.target.attributes[1].value;
	o.value = e.target.firstChild.wholeText;
	for (var i=0;i<e.target.obj.listeners.length;i++)
	{
		e.target.obj.listeners[i].onColumnSelect(o);
	}	
}
URIGrid.prototype.onClick = function (e)
{
	var o = {};
	o.target = e.target;
	o.field = e.target.attributes[0].value;
	o.value = e.target.firstChild.wholeText;

	for (var i=0;i<e.target.obj.listeners.length;i++)
	{
		e.target.obj.listeners[i].onGridSelect(o);
	}	
}
URIGrid.prototype.onIconClick = function(e)
{
	var o = {};
	o.target = e.target;
	o.field = e.target.attributes[2].value;
	o.value = e.target.attributes[1].value;

	for (var i=0;i<this.listeners.length;i++)
	{
		this.listeners[i].onIconClick(o);
	}	
}
URIGrid.prototype.onMouseOver = function (e)
{
	for (var i=0;i<e.target.obj.listeners.length;i++)
	{
		e.target.obj.listeners[i].onGridMouseOver(e);
	}	
}
