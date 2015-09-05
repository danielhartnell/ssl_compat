function PageController(range, start, callback)
{
	PageController.END_GLYPH = String.fromCharCode(9193);
	PageController.START_GLYPH = String.fromCharCode(9194);
	PageController.FORWARD_GLYPH = String.fromCharCode(9658);
	PageController.BACK_GLYPH = String.fromCharCode(9668);

	this.limit = range;
	this.position = start;
	this.listener = callback;
	
	//return 0;
	return this.init(range, start);
}

PageController.prototype.init = function(range, start_num)
{
	var container = Utility.createElement("p", [{align:"right"}]);
	var id = document.createAttribute("id");
	id.value="page_controller";
	container.setAttributeNode(id);

	var start = Utility.createElement("a", [{id:"start"}]);
	start.href="#";
	start.onclick = this.onSelect.bind(this);

	var start_label = document.createTextNode(PageController.START_GLYPH);
	start.appendChild(start_label);
	container.appendChild(start);	

	var back = Utility.createElement("a", [{id:"back"}]);
	back.href="#";
	back.onclick = this.onSelect.bind(this);

	var back_label = document.createTextNode(PageController.BACK_GLYPH);
	back.appendChild(back_label);

	var current = Utility.createElement("text", [{id:"current"}]);
	this.current_label = document.createTextNode(start_num);
	current.appendChild(this.current_label);

	var maximum = Utility.createElement("text", [{id:"maximum"}]);
	this.maximum_label = document.createTextNode("/ " + range);
	maximum.appendChild(this.maximum_label);

//
	var forward = Utility.createElement("a", [{id:"forward"}]);
	forward.href="#";
	forward.onclick = this.onSelect.bind(this);

	var forward_label = document.createTextNode(PageController.FORWARD_GLYPH);
	forward.appendChild(forward_label);

	var end = Utility.createElement("a", [{id:"end"}]);
	end.href="#";
	end.onclick = this.onSelect.bind(this);

	var end_label = document.createTextNode(PageController.END_GLYPH);
	end.appendChild(end_label);

	Utility.appendChildren(container, start,back,current,maximum,forward,end);
	return container;
}
PageController.prototype.onSelect = function (arg)
{

	var target = arg.target.attributes[0].value;
	if ( target == "forward" )
	{
		if (this.position < this.limit)
		{
			this.position++;
			this.current_label.data = this.position;
		}
	} else if ( target == "back" )
	{
		if (this.position > 1)
		{
			this.position--;
			this.current_label.data = this.position;
		}
	} else if ( target == "start" )
	{
			this.position=1;
			this.current_label.data = this.position;
	} else if ( target == "end" )
	{
			this.position=this.limit;
			this.current_label.data = this.position;
	}

	this.listener(this.position);
}
PageController.prototype.setLimit = function (arg)
{
	this.limit = arg;
}


// logic to control back/fwd
// grey out controls

