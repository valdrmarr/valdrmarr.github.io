function util(){function t(t){return null!==t&&("function"==typeof t||"object"==typeof t)}function r(r,n){var e=new Date,a=d3.format("0>2")(e.getDate())+"/"+d3.format("0>2")(e.getMonth()+1)+"/"+e.getFullYear()+" "+d3.format("0>2")(e.getHours())+":"+d3.format("0>2")(e.getMinutes())+":"+d3.format("0>2")(e.getSeconds())+"."+d3.format("0>3")(e.getMilliseconds()),i=a+" "+r+":";t(n)?(console.log(i),console.log(n)):console.log(i+" "+n)}function n(t,r,n){var e=new RegExp("([?&])"+r+"=.*?(&|$)","i"),a=t.indexOf("?")!==-1?"&":"?";return t.match(e)?t.replace(e,"$1"+r+"="+n+"$2"):t+a+r+"="+n}this.logger={},this.logger.mode=0,this.logger.debug=function(t){logger.mode>1&&r("DEBUG",t)},this.logger.error=function(t){logger.mode>-1&&r("ERROR",t)},this.logger.trace=function(t){logger.mode>0&&r("TRACE",t)},this.formatInt=function(t){return d3.format(".0f")(t)},this.addText=function(t,r,n,e){for(var a=t.append("text").attr("transform","translate("+r+","+n+")"),i=[],o=0;o<e.length;o++){var u=a.append("tspan").text(e[o].value);for(var d in e[o])"d"==d?u.d=e[o][d]:"value"!=d&&u.attr(d,e[o][d]);i.push(u)}return a},this.addRect=function(t,r,n,e,a){return t.append("rect").attr("x",r).attr("y",n).attr("width",e).attr("height",a)},this.addHorizontalLine=function(t,r,n,e,a){return this.addLine(t,r,r+e,n,n,a)},this.addVerticalLine=function(t,r,n,e,a){return this.addLine(t,r,r,n,n+e,a)},this.addLine=function(t,r,n,e,a,i){return t.append("line").attr("x1",r).attr("y1",e).attr("x2",n).attr("y2",a).attr("stroke-dasharray",i)},this.addImage=function(t,r,n,e){return t.append("svg:image").attr("xlink:href",r).attr("x",0).attr("y",0).attr("width",n).attr("height",e)},this.addCircle=function(t,r,n,e){return t.append("circle").attr("cx",r).attr("cy",n).attr("r",e)},this.setQueryVariable=function(t,r){window.parent.history.pushState("","",n(window.parent.location.href,t,r))},this.getQueryVariable=function(t){for(var r=window.parent.location.search.substring(1),n=r.split("&"),e=0;e<n.length;e++){var a=n[e].split("=");if(a[0]==t)return a[1]}return!1},this.hashCode=function(t){var r=0;if(null==t||0==t.length)return r;for(i=0;i<t.length;i++)char=t.charCodeAt(i),r=(r<<5)-r+char,r&=r;return r},this.average=function(t){var r=0;for(var n in t)r+=t[n];return r/t.length},this.sortAssociativeArray=function(t,r,n){var e=[],a={};for(var i in t)e.push([i,t[i]]);e.sort(function(t,r){return t=t[1],r=r[1],n(t,r)});for(var o=0;o<e.length;o++){var i=e[o][0],u=e[o][1];u[r]=o,a[i]=u}return a}}function refineData(t){for(var r={},n=0;n<t.length;n++)r[t[n].key]=t[n].data;return r}util.loadData=function(t,r,n){logger.trace("Loading: "+r[t].path),d3.csv(r[t].path,function(e,a){r[t].data=a,t>=r.length-1?n(refineData(r)):util.loadData(t+1,r,n)})};