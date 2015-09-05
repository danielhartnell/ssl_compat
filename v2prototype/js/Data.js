/*
This class takes raw data and formats it into various things:
- Array of URI list items
- An object containing metadata
- An array of objects that can be fed into a chart component

*/


// TODO: need more methods for extracting metadata

function Data ()
{
	this.name = "Data";
}

Data.parseDocument = function(arg)
{
	var temp1 = arg.toString().split("+++ ");
	//var temp2 = temp1[1].split("--- ")[1];
	//var temp3 = temp2.split("\n");
	var temp4 = temp1[1].split("\n");
	//alert(temp4[0])
	var uriObjectArray = [];
	//temp3.splice(0,1)
	for (var i=0;i<temp4.length;i++)
	{
		try
		{
			uriObjectArray.push (Data.makeURIObject(temp4[i]));
		} catch (e)
		{
			//alert("Bad JSON detected");
		}
	}
	var o = {};
	o.metadata = temp1[0]; // new Data() ?
	o.uriList = uriObjectArray;
	return o;
}

Data.makeURIObject = function (str)
{
	var p = str.indexOf("{");
	if (p == -1)
	{
		throw new Error();
	}
	var temp1 = str.substring(p);
	var o = {};
	var temp2 = JSON.parse(temp1)
	for (var i in temp2)
	{
		o[i] = temp2[i];
	}
	return o;
}

Data.getPieGraphData = function(uriList, fieldName)
{
	var obj = [];
	for (var i=0;i<uriList.length;i++)
	{
		var str = eval ("uriList[" + i + "]." + fieldName);
		var temp = eval ("obj['" + str +"']");
		if (temp == null)
		{
			eval ("obj['" + str + "']=1;")
		} else {
			temp++;
			eval ("obj['" + str + "']= " + temp + ";")
		}
	}
	var fields = [];
	for (var field in obj)
	{
		var temp = {};
		temp.label = field;
		temp.value = obj[field];
		fields.push(temp);
	}

	var colorArray = returnColorArray(fields.length);
	for (var i=0;i<fields.length;i++)
	{
		fields[i].color = colorArray[i];
	}
    return fields;  
}

Data.sortByField = function (uriList, fieldName)
{
	uriList.sort(function(arg1,arg2)
		{
			var a = eval ("arg1." + fieldName);
			var b = eval ("arg2." + fieldName);
			return a == b ? 0 : (a < b ? -1 : 1);
		});
	return uriList;
}
Data.filterBy = function (uriList, fieldName, value, remove)
{
	var temp = [];
	for ( var i=0;i<uriList.length;i++ )
	{
		var found = eval ("uriList[" + i + "]." + fieldName + "=='" + value + "'");
		if ( ( !found && remove ) || ( found && !remove ) )
		{
			temp.push (uriList[i]);
		} 
	}
	return temp;
}

/*
Data.prototype.getBarGraphData = function(uriList, fieldName)
{
    var data = {
    labels: ["January", "February", "March", "April", "May", "June", "July"],
    datasets: [
        {
            label: "My First dataset",
            fillColor: "rgba(220,220,220,0.2)",
            strokeColor: "rgba(220,220,220,1)",
            pointColor: "rgba(220,220,220,1)",
            pointStrokeColor: "#fff",
            pointHighlightFill: "#fff",
            pointHighlightStroke: "rgba(220,220,220,1)",
            data: [65, 59, 80, 81, 56, 55, 40]
        },
        {
            label: "My Second dataset",
            fillColor: "rgba(151,187,205,0.2)",
            strokeColor: "rgba(151,187,205,1)",
            pointColor: "rgba(151,187,205,1)",
            pointStrokeColor: "#fff",
            pointHighlightFill: "#fff",
            pointHighlightStroke: "rgba(151,187,205,1)",
            data: [28, 48, 40, 19, 86, 27, 90]
        }
    ]};
    return data;  
}
*/
