function TLSCanary(div)
{
    this.name = "TLSCanary";
    this.dataURL;
    this.tabs = [];
    this.currentTabIndex;
    this.DEFAULT_TAB = 1;
    this.masterDiv = div;
}
TLSCanary.prototype.getMouse = function(e)
{
    this.mouseX = e.pageX;
    this.mouseY = e.pageY;
}
TLSCanary.prototype.init = function()
{
    document.captureEvents(Event.MOUSEMOVE); // TODO: addEventListener
    document.onmousemove = this.getMouse.bind(this);

    this.defaultView = ["site_info.uri","error.code","error.type","error.message"];


    // TODO: load data
    this.testData = 'test metadata\n+++ blah\n--- blah\nwww.site.com    {"site_info":{"uri":"www.site.com","rank":1, "connection_time":2000},"error":{"code":"0x000000","type":"network","message":"site_not_found"},"tls_info":{"version":"1.2","cypher_suite":"", "key_length":0, "secret_key_length":0},"cert_info":{"chain_length":3,"ev":"false","issuer":"GeoTrust", "date":"1/1/15","cert_chain":"issuer CN fields"}}\nwww.anothersite.com    {"site_info":{"uri":"www.anothersite.com","rank":2, "connection_time":200},"error":{"code":"0x0000ff","type":"protocol","message":"no_cypher_overlap"},"tls_info":{"version":"1.0","cypher_suite":"", "key_length":0, "secret_key_length":0},"cert_info":{"chain_length":3,"ev":"true","issuer":"Equifax", "date":"2/1/16","cert_chain":"issuer CN fields"}}\nwww.blah.com    {"site_info":{"uri":"www.blah.com","rank":1, "connection_time":10000},"error":{"code":"0x000000","type":"certificate","message":"unknown_issuer"},"tls_info":{"version":"","cypher_suite":"", "key_length":0, "secret_key_length":0},"cert_info":{"chain_length":0,"ev":"true","issuer":"", "date":"","cert_chain":{}}}';  
    var doc = Data.parseDocument(this.testData);
    this.metadata = doc.metadata;

    //this.uriList = doc.uriList;
    this.uriList = fakeData;
    this.makeViewObject(this.uriList[0], this.defaultView);
    this.updateView();

    // make tabs
    this.currentTabIndex = this.DEFAULT_TAB;
    this.addTab("Fields", true, this.fieldList, "", this.makeFieldsUI);
    this.addTab("Grid", true, Data.sortByField(this.uriList, "site_info.uri"), "site_info.uri", this.makeGrid);
    this.addTab("Chart : error.message", true, this.uriList, "error.message", this.makeChart);


    // TODO: process metadata, change page title

    // add tab component
    this.tc = new TabContainer(this.masterDiv);
    this.tc.setTitle("test metadata goes here!");
    this.tc.createTabs (this.tabs);
    this.tc.drawTabs();
    this.tc.changeTabSelection(this.DEFAULT_TAB);
    this.tabListener = {};
    this.tabListener.onChange = this.onTabChange.bind(this);
    this.tabListener.onRemove = this.removeTab.bind(this);
    this.tc.addListener(this.tabListener);
    this.tabs[this.DEFAULT_TAB].action(1);
}

TLSCanary.prototype.makeViewObject = function (obj, view)
{
    this.fieldList = [];
    this.viewObject = {};
    for (var i in obj)
    {
        this.viewObject[i] = {};
        for (var j in obj[i])
        {
            this.fieldList.push( i + "." + j);
            this.viewObject[i][j]= false;
        } 
    }
    for (var k=0;k<view.length;k++)
    {
        eval ("this.viewObject." + view[k] + " = true;")
    }
}

TLSCanary.prototype.updateView = function()
{
    // apply current view object to view array
    var newViewArray = [];
    for (var i=0;i<this.fieldList.length;i++)
    {
        if (eval ("this.viewObject." + this.fieldList[i]))
        {
            newViewArray.push(this.fieldList[i]);
        }
    }
    this.currentView = newViewArray;
}
TLSCanary.prototype.onTabChange = function(arg)
{
    this.currentTabIndex = arg;
    this.tabs[arg].action(arg);
}

TLSCanary.prototype.makeChart = function(arg)
{
    var table = Utility.createElement("table", [{width:"100%"}]);
    var tr = Utility.createElement("tr");
    var td1 = Utility.createElement("td");
    var td2 = Utility.createElement("td");
    table.style.border = "none";
    td1.style.border = "none";
    td2.style.border = "none";

    var chartData = Data.getPieGraphData(this.tabs[arg].data, this.tabs[arg].field);
    var totalSites = this.tabs[arg].data.length;
    var totalUniqueErrors = chartData.length;
    var msg = this.tabs[arg].field + ": " + totalSites + " sites total, " + totalUniqueErrors + " unique values";
    var label = Utility.createElement("label");
    var str = document.createTextNode(msg);
    label.appendChild(str);
    td1.appendChild(label);
    Utility.appendChildren(tr, td1, td2);
    table.appendChild(tr);

    var myCanvas = Utility.createElement("canvas");
    myCanvas.width=400;
    myCanvas.height=300;    
    var myDiv = Utility.createElement("div");
    Utility.appendChildren (myDiv, table, Utility.createElement("p"), myCanvas)
    ctx2 = myCanvas.getContext("2d");
    this.tc.setContent (myDiv);
    var myPieChart = new Chart(ctx2).Pie(chartData, {animation:false});
}
TLSCanary.prototype.makeGrid = function(arg)
{
    //this.updateView();
    var currentTab = this.tabs[arg];
    this.grid = new URIGrid(currentTab.data, this.currentView, currentTab.field, currentTab.sortOrder);
    this.grid.addListener (this);
    this.tc.setContent(this.grid.html);
}

TLSCanary.prototype.makeFieldsUI = function(arg)
{
    var myDiv = Utility.createElement("div");
    var myForm = Utility.createElement("form", [{id:"checkboxes"}]);
    var fields = this.tabs[arg].data;
    for (var i=0;i<fields.length;i++)
    {
        var checkboxAttributes = [{type:"checkbox"}, {name:"ui_fields"}, {value:fields[i]}];
        if (eval("this.viewObject." + fields[i]))
        {
            checkboxAttributes.push({checked:"checked"});     
        }

        var checkbox = Utility.createElement("input", checkboxAttributes);
        checkbox.onclick = this.onUpdateCheckbox.bind(this);
        var label = Utility.createElement("label");
        var str = document.createTextNode(fields[i]);
        label.appendChild(str);
        Utility.appendChildren (myForm, checkbox, label, Utility.createElement("br"));
    }
    myDiv.appendChild(myForm);
    this.tc.setContent(myDiv);
}

TLSCanary.prototype.onUpdateCheckbox = function (arg)
{
    var checked = false;
    if (arg.target.checked)
    {
        checked = true;
    }
    var name = arg.target.attributes[2].value;
    eval ("this.viewObject." + name + "=" + checked + ";");
    this.updateView();
}

TLSCanary.prototype.onColumnSelect = function (arg)
{
    var currentTab = this.tabs[this.currentTabIndex];
    var newData = Data.sortByField(currentTab.data, arg.field);
    if (arg.field == currentTab.field)
    {
        currentTab.sortOrder = Number(!Boolean(currentTab.sortOrder));
        if (currentTab.sortOrder)
        {
            newData.reverse();
        }
    } else {
        currentTab.sortOrder = 0;
    }
    currentTab.field = arg.field;
    this.grid.setSelectedColumn(arg.field);
    this.grid.setSortOrder(currentTab.sortOrder);
    this.grid.redraw(newData, this.currentView);
    this.tc.setContent(this.grid.html);
    currentTab.data = newData;
}

TLSCanary.prototype.onGridSelect = function (arg)
{
    var list = Utility.createElement("ul");
    var item1 = Utility.createElement("li");
    var removeAttributes = [{id:"remove"}, {href:"#"}, {field_name:arg.field}, {value:arg.value}];
    var removeItem = Utility.createElement("a", removeAttributes);
    removeItem.onclick = this.onFilter.bind(this);
    item1.appendChild(removeItem);
    removeItem.appendChild(document.createTextNode("remove all"));

    var item2 = Utility.createElement("li");
    var filterAttributes = [{id:"filter"}, {href:"#"}, {field_name:arg.field}, {value:arg.value}];
    var filterItem = Utility.createElement("a", filterAttributes);
    filterItem.onclick = this.onFilter.bind(this);
    item2.appendChild(filterItem);
    filterItem.appendChild(document.createTextNode("show only"));
    Utility.appendChildren(list, item1, Utility.createElement("br"), item2);
    this.showFloater (list);
}
TLSCanary.prototype.showFloater = function (content)
{
    this.grid.floater.style.visibility = "visible";
    this.grid.floater.style.position = "absolute";
    this.grid.floater.style.left = (this.mouseX + 10) + "px";
    this.grid.floater.style.top = (this.mouseY - 20) + "px"; 
    this.grid.floater.innerHTML = "";
    this.grid.floater.appendChild(content); 
}
TLSCanary.prototype.onGridMouseOver = function(arg)
{
    this.grid.floater.style.visibility = "hidden";
}
TLSCanary.prototype.onFilter = function(arg)
{
    this.onGridMouseOver(arg);
    var remove = arg.target.attributes[0].value == "remove";
    var field = arg.target.attributes[2].value;
    var value = arg.target.attributes[3].value;
    var newData = Data.filterBy(this.tabs[this.currentTabIndex].data, field, value, remove);
    this.grid.redraw(newData, this.currentView);
    this.tc.setContent(this.grid.html);
    this.tabs[this.currentTabIndex].data = newData;
}
TLSCanary.prototype.onIconClick = function (e)
{
    if (e.value == "delete")
    {
        eval ("this.viewObject." + e.field + "=false;");
        this.updateView();
        this.grid.redraw(this.tabs[this.currentTabIndex].data, this.currentView);
        this.tc.setContent(this.grid.html);
    } else if (e.value == "chart")
    {
        this.addTab("New Chart : " + e.field, false, this.tabs[this.currentTabIndex].data, e.field, this.makeChart);
    }
}

TLSCanary.prototype.addTab = function (label, permanent, data, field, callback)
{
    var newTab = new Tab({label:label});
    newTab.data = data;
    newTab.field = field;
    newTab.permanent = permanent;
    newTab.sortOrder = 0;
    newTab.index = this.tabs.length-1;
    newTab.action = callback.bind(this);
    try{
        this.tabs.push(newTab);
        this.tc.addTab(newTab);
    } catch (e) {
        // no tab container available
    }
}
TLSCanary.prototype.removeTab = function (index)
{
    if (index <= this.currentTabIndex && index != this.tabs.length-2)
    {
        this.currentTabIndex--;
    } 
    this.tabs.splice (index, 1);
    this.tc.updateTabs (this.tabs, this.currentTabIndex);
    this.tc.changeTabSelection(this.currentTabIndex)
    this.doTabAction(this.currentTabIndex)
}
