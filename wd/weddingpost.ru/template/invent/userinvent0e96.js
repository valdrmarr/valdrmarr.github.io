function translite(e){for(var t=new Array("Я","я","Ю","ю","Ч","ч","Ш","ш","Щ","щ","Ж","ж","А","а","Б","б","В","в","Г","г","Д","д","Е","е","Ё","ё","З","з","И","и","Й","й","К","к","Л","л","М","м","Н","н","О","о","П","п","Р","р","С","с","Т","т","У","у","Ф","ф","Х","х","Ц","ц","Ы","ы","Ь","ь","Ъ","ъ","Э","э"),s=new Array("Ya","ya","Yu","yu","Ch","ch","Sh","sh","Sh","sh","Zh","zh","A","a","B","b","V","v","G","g","D","d","E","e","E","e","Z","z","I","i","J","j","K","k","L","l","M","m","N","n","O","o","P","p","R","r","S","s","T","t","U","u","F","f","H","h","C","c","Y","y","","","","","E","e"),a=0;a<t.length;a++){var n=new RegExp(t[a],"g");e=e.replace(n,s[a])}return e}function textConfetty(e,t){confetti({angle:-0,particleCount:120,spread:120,origin:{y:t,x:e},gravity:1,scalar:.55,decay:.98,drift:1,colors:["#ffffff","#ffbf00","#a77b01","#ffdb73"],startVelocity:4})}function alignText(e,t){if("center"==t||"right"==t){var s=$.cookie("textWidth");if("center"==t)var a=(e.width()-s)/2;else if("right"==t)var a=e.width()-s;var n=e.parent(".moveBox").parent(".textBox").width(),o=100*a/n;left_now=e.parent(".moveBox").get(0).style.left.slice(0,-1),e.parent(".moveBox").css("left",left_now-1+1-o+"%")}}function replaceOnMaket(e,t,s,a){if(str=e.html(),str=str.replace(/&gt;/g,">"),str=str.replace(/&lt;/g,"<"),(s||"undefined"!=typeof s)&&(str.indexOf("Жених")+1||str.indexOf("Ж")+1||str.indexOf("К")+1||str.indexOf("ЖЕНИХ")+1)){var n=s.charAt(0).toUpperCase();str=str.replace(/Жених/g,s).replace(/ЖЕНИХ/g,s.toUpperCase()),str=str.replace(/Ж/g,n).replace(/К/g,n)}if((t||"undefined"!=typeof t)&&(str.indexOf("Невеста")+1||str.indexOf("Н")+1||str.indexOf("М")+1||str.indexOf("НЕВЕСТА")+1)){var o=t.charAt(0).toUpperCase();str=str.replace(/Невеста/g,t).replace(/НЕВЕСТА/g,t.toUpperCase()),str=str.replace(/Н/g,o).replace(/М/g,o)}if(a||"undefined"!=typeof a){var r=a.split(".");if((/[0-9]{2}.[0-9]{2}.[0-9]{4}/g.test(str)||/[0-9]{4}/g.test(str))&&(str=str.replace(/[0-9]{2}.[0-9]{2}.[0-9]{4}/g,a),str=str.replace(/[0-9]{4}/g,r[2])),str.indexOf("ентябрь")+1||str.indexOf("ентября")+1||str.indexOf("СЕНТЯБРЬ")+1||str.indexOf("СЕНТЯБРЯ")+1||str.indexOf("28")+1){var i=Number(r[1]).toString();str=str.toLowerCase();var l=new Array("","январь","февраль","март","апрель","май","июнь","июль","август","сентябрь","октябрь","ноябрь","декабрь");str=str.replace(/сентябрь/g,l[i]);var c=new Array("","января","февраля","марта","апреля","мая","июня","июля","августа","сентября","октября","ноября","декабря");str=str.replace(/сентября/g,c[i]),str=str.replace(/28/g,r[0])}}$.cookie("textWidth",e.width());var d=e.css("text-align");e.html(str),alignText(e,d)}function changeIframe(e,t,s,a){a||(a=0),setTimeout(function(){confetti.reset(),textConfetty(.2,.2),textConfetty(.1,.3),textConfetty(.1,.1),$("#mymain .textBox .moveBox:not([type=img]) .textLine, #mainInv .textBox .moveBox:not([type=img]) .textLine").each(function(a,n){replaceOnMaket($(this),e,t,s)}),$.cookie("var_she")&&$.cookie("var_he")&&$(".screenshot_iphone .domain strong").text(translite($.cookie("var_he")).toLowerCase()+"-i-"+translite($.cookie("var_she")).toLowerCase()+".ru"),"undefined"!=typeof $(".iFrame iframe").get(0).contentWindow&&$(".iFrame iframe").get(0).contentWindow.changeIframe(e,t,s,2e3)},a)}function acceptInvite(e){function t(e,t){return Math.random()*(t-e)+e}if(1==e){confetti({angle:t(55,125),spread:t(50,70),particleCount:t(50,100),origin:{y:.6}});var s,a=$(document).width();s=a<500?2:8;var n=Date.now()+1e3*s,o=[];$(".colors .color").each(function(e,t){"undefined"!=typeof $(this).attr("bg")&&o.push($(this).attr("bg"))}),console.log(o),o[0]&&function e(){confetti({particleCount:3,angle:60,spread:40,origin:{x:0},colors:o}),confetti({particleCount:3,angle:120,spread:40,origin:{x:1},colors:o}),Date.now()<n&&requestAnimationFrame(e)}(),1==$(".guestAgree[answer=1]").attr("data-opros")&&($("#opros").fadeIn(),$("#screen").scrollTo("#opros")),$(".guestAgree[answer=1]").addClass("hide"),$(".iAgree").removeClass("hide"),$(".cancelLink").removeClass("hide"),$(".acceptLink").addClass("hide")}else 0==e?(1==$(".guestAgree[answer=1]").attr("data-opros")&&($("#opros").fadeOut(),$("#weddingOpros label i").removeClass("fa-check-circle").addClass("fa-circle-o"),$("#weddingOpros input").removeAttr("checked")),$(".cancelLink").addClass("hide"),$(".acceptLink").removeClass("hide"),$(".guestAgree[answer=1]").removeClass("hide"),$(".iAgree").addClass("hide"),$(".commentBox").show(),$(".addComment").css("visibility","hidden"),$(".commentBox input[name=withMoney]").attr("checked","checked"),$(".commentBox .moneyBox").removeClass("hide"),$(".commentBox textarea").addClass("errorInput1px")):($(".guestAgree").addClass("hide"),$(".iAgree").removeClass("hide"),e=1);$.ajax({url:window.location.origin+"/template/invent/userinvent.php",data:{Action:"guestAgree",answer:e,guest:guest_id},type:"post",success:function(e){}})}function nl2br(e){return e.replace(/([^>])\n/g,"$1<br/>")}function br2nl(e){return e.replace(/<br>/g,"\n")}function replaceYou(e,t){var s;return s="tu"==t?e.replace(/Вас/g,"тебя").replace(/Вам/g,"тебе").replace(/Вы/g,"ты"):e.replace(/тебя/g,"Вас").replace(/тебе/g,"Вам").replace(/ ты/g," Вы")}function getQR(e,t,s){var a="https://wdpst.ru/"+t+"/"+s;Bcolor=$(e+" .backQR").attr("Bcolor"),Bcolor&&"undefined"!=typeof Bcolor||(vallColor=$(e+" .backQR").get(0).style.background,vallColor||(vallColor=$(e+" .backQR").get(0).style.backgroundColor),Bcolor=getHexColor(vallColor).slice(1),$(e+" .backQR").attr("Bcolor",Bcolor),$(e+" .backQR").css("background","")),vallColor=$(e+" .frontQR").get(0).style.background,vallColor||(vallColor=$(e+" .frontQR").get(0).style.backgroundColor),Fcolor=getHexColor(vallColor).slice(1),$(e+" .frontQR").hide(),$(e+" .backQR").css("background-image","url(https_/wdpst.store/QRgen77c2.html?user_id="+t+"&guest="+s+"&backQR="+Bcolor+"&frontQR="+Fcolor+"&link="+a+")"),$(e+" qr_link").text(a)}function getHexColor(e){if(e=e.replace(/\s/g,""),e.indexOf("rgba")+1){var t=e.lastIndexOf(",")-e.length;e="rgb("+e.slice(0,t).substr(5)+")"}var s=e.match(/^rgb\((\d{1,3}[%]?),(\d{1,3}[%]?),(\d{1,3}[%]?)\)$/i);colorHEX="";for(var a=1;a<=3;a++)colorHEX+=Math.round(("%"==s[a][s[a].length-1]?2.55:1)*parseInt(s[a])).toString(16).replace(/^(.)$/,"0$1");return"#"+colorHEX}function makeDearGuest(){var e=$("#mainInv .back dear_guest").parent(".textLine");"undefined"!=typeof e.attr("font")&&e.css("font-size",e.attr("font")),"undefined"!=typeof e.attr("line")&&e.css("line-height",e.attr("line"));var t=e.css("line-height").slice(0,-2),s=2*parseInt(t)+4,a=e.css("height").slice(0,-2);e.css("transition","none");for(var n=.05;a>s;){var o=e.css("font-size").slice(0,-2),r=e.css("line-height").slice(0,-2);e.css("font-size",.96*o+"px").css("line-height",.95*r+"px"),a=e.height(),n=.05+n}}function showComment(e,t,s,a){$(".commentBox").addClass("hide"),$(".addComment").css("visibility","hidden"),$(".commentYes .andGift").addClass("hide"),$(".commentYes").removeClass("hide"),$(".commentYes .commentFromGuest span").html(nl2br(t)),$(".commentYes .author").html(e),($("input[name=withMoney").is(":checked")||"undefined"!=typeof s&&"0"!=s&&s)&&($(".commentYes .andGift").removeClass("hide"),$(".commentYes .andGift div").text(s)),"undefined"==typeof a&&(a="Только что"),$(".commentYes .time").text(a)}function typePaper(e){var t=$(".sheet .back dear_guest").parent(),s=t.css("color");if(s="undefined"!=typeof s?s.indexOf("rgba")+1?s.slice(0,-4).substr(5):s.slice(0,-1).substr(4):"#000",t.parent().children("span").remove(),t.parent().append("<span style='bottom:10px; position:relative; display:block; border-bottom:2px solid rgb("+s+")'></span>"),"noname"==e||1==e){t.html();t.parent().children("span").removeClass("hide"),t.css("opacity",0)}else t.parent().children("span").addClass("hide"),t.css("opacity",100)}function makeSexWords(e,t){var s=e.match(/([^\s,]+\|[^\s,]+\|[^\s,]+)/g);return t&&s&&$.each(s,function(s,a){switch(t){case"he":var n=a.split("|")[0];break;case"she":var n=a.split("|")[1];break;case"they":var n=a.split("|")[2]}e=e.replace(a,n)}),e}function makeHotwords(e,t){e=e.replace(new RegExp("Имя<br>гостя","g"),"<ГОСТЬ>"),e.indexOf("<img")+1==0&&e.indexOf("<a")+1==0&&e.indexOf("<iframe")+1==0&&e.indexOf("<ГОСТЬ>")+1==0&&1==getUrlVar().paper|2==getUrlVar().paper|!getUrlVar().paper,e=e.replace(new RegExp("/&gt;/i","g"),">"),e=e.replace(new RegExp("/&lt;/i","g"),"<"),e=e.replace(new RegExp("<ЖЕНИХ>","g"),"Жених"),e=e.replace(new RegExp("<НЕВЕСТА>","g"),"Невеста");var s={date:"<ДАТА>",time:"<ВРЕМЯ>",he:"Жених",she:"Невеста",place:"<МЕСТО>",address:"<АДРЕС>",guest:"<ГОСТЬ>"};return $.each(s,function(s,a){if(e.indexOf(a)+1){if(t)var n=t[s];else var n=$("#constructorContent input[name="+s+"]").val();"__.__.____"!=n&&"__:__"!=n||(n=""),""==n&&(n="&ensp;"),e=e.replace(new RegExp(a,"g"),n)}}),e}function autoTextarea(e,t){for(var s=e.value,a=s.match(/^.*(\r\n|\n|$)/gim),n=!1,o=0;o<a.length;o++)s=a[o].replace(/\r|\n/g,""),n+=s.length?Math.ceil(s.length/35):1;t&&n<t&&(n=t),e.rows=n}function getUrlVar(){var e=window.location.search,t=[],s=[],a=[];if(t=e.substr(1).split("&"),""==t[0])return!1;for(i=0;i<t.length;i++)s=t[i].split("="),a[s[0]]=s[1];return a}function getInvs(e,t,s){var a;a=getUrlVar().mode?getUrlVar().mode:getUrlVar().paper&&"underfined"!=getUrlVar().paper?getUrlVar().paper:0,$.ajax({url:window.location.origin+"/template/invent/userinvent.php",data:{Action:"getInv",user_id:e,guest:t,type:s,style_id:getUrlVar().style_id,screenshot:getUrlVar().screenshot,mode:a},type:"post",complete:function(e){function t(){var e=new ymaps.Map("map",{center:[55.753994,37.622093],zoom:4});if(user_coord){coord=user_coord.split(",");var t=new ymaps.Placemark([coord[0],coord[1]]);e.geoObjects.add(t),e.setCenter([coord[0],coord[1]],16),e.behaviors.disable("scrollZoom")}$(window).width()<750&&(e.behaviors.disable("drag"),e.behaviors.disable("scrollZoom"))}getUrlVar().opros_result||getUrlVar().show_comment||"electro"!=s||ymaps.ready(t)},success:function(t){if(""!=t.userdata){usercontent=JSON.parse(t.userdata),t.guest_name||(t.guest_name="Гость"),t.guest_sex||(t.guest_sex="he"),t.domain?t.domain=JSON.parse(t.domain)[1].domain:t.domain="weddingpost.ru/"+t.user_id;var a={date:usercontent.timing.date,time:usercontent.timing.time,he:usercontent.he,she:usercontent.she,place:usercontent.timing.place,address:usercontent.timing.address,guest:t.guest_name,sex:t.guest_sex,money:usercontent.money}}if("electro"==s){$(".content").html(t.electro_content);var n=$(".plate_box .element1[action=plate]"),o=n.css("background");if(o&&o.indexOf("https://weddingpost.ru/plate/")+1&&!o.indexOf("../../plate/all/none.html")+1&&n.parent().addClass("plate-design"),"mobile_preview"==getUrlVar().mode&&$(window).width()<750&&($("#menu").css("padding-top","12px").css("height","73px"),$("#mymain").css("padding-top","12px")),t.guest_comment){var r=JSON.parse(t.guest_comment);showComment(t.guest_name,r.text,r.moneyText,t.guest_commenttime)}else $(".commentBox").hide()}else"paper"==s&&($(".content").html(t.paper_content),$(".content").attr("id",""),$(".sheetview").children("div").removeClass("bottomPaperFade"),$(".textLine").css("transition","none"));if($("[var=she]").html(a.she),$("[var=he]").html(a.he),"Гость"!=a.guest&&$("[var=guest]").html(a.guest),t.guest_title&&$("dear_guest").html(t.guest_title),a.money&&$(".withMoney").attr("link","https://yoomoney.ru/to/"+a.money+"/"),$(".content .sheet").css("display","block").css("marginTop","0px"),$(".sheetview").css("margin-left","0px","important").css("margin-top","0px","important"),$(".allsheet").css("margin-top","0px","important"),"QR"==getUrlVar().from&&(setTimeout(function(){$("html,body").stop().animate({scrollTop:$("#agree").offset().top-100},1e3)},3e3),setTimeout(function(){acceptInvite(1)},4200),console.log("form=QR")),1==getUrlVar().screenshot&&"PDF"!=getUrlVar().for&&getUrlVar().paper&&777!=getUrlVar().paper&&999!=getUrlVar().paper&&888!=getUrlVar().paper){51==getUrlVar().paper||52==getUrlVar().paper?AA="A4":AA="A6";var i="template/invent/?user="+getUrlVar().user+"&screenshot=1&for=PDF&paper="+getUrlVar().paper+"&guest="+getUrlVar().guest+"&table="+getUrlVar().table;return $(".content").html('<div class="PDFgen '+AA+'"><iframe style="border:0px;" width = "100%" height = "100%" src = "'+window.location.origin+"/"+i+'"></iframe></div></div>'),!1}if("PDF"==getUrlVar().for&&$(".content").addClass("PDFcontainer"),2==getUrlVar().paper){if($(".moveBox[type=QR]").css("visibility","hidden"),guest_id&&0!=guest_id&&1!=guest_id?(typePaper("name"),makeDearGuest(),$(".sheet#mainInv .back .moveBox[type=QR]:not([delete])").length&&(getQR(".sheet#mainInv .back",e,guest_id),$(".moveBox[type=QR]").css("visibility","visible"))):typePaper("noname"),$(".sheet").addClass("hide"),$(".sheet#mainInv").removeClass("hide"),$(".sheet#mainInv .front").addClass("hidden"),$(".sheet#mainInv .back").removeClass("hidden").css("transform","none"),JSON.parse(t.PDFattr)){var l=JSON.parse(t.PDFattr);"v2"==l.maket?$("#mainInv .back").addClass("maket_v2"):"v3"==l.maket?$("#mainInv .back").addClass("maket_v3"):"v4"==l.maket&&$("#mainInv .back").addClass("maket_v4")}$("#mainInv .textBox .textLine").each(function(e,t){var s=$(this).html();"tu"==l.for?$(this).html(s.replace(/(Вас|Вы|Вам)([.!;\-, ]|$)/g,function(e,t,s,a){return replaceYou(e,"tu")})):$(this).html(s.replace(/(тебя|ты|тебе)([.!;\-, ]|$)/g,function(e,t,s,a){return replaceYou(e,"voce")}))})}else if(1==getUrlVar().paper)$(".sheet").addClass("hide"),$(".sheet#mainInv").removeClass("hide"),$(".sheet#mainInv .back").addClass("hidden"),$(".sheet#mainInv .front").removeClass("hidden").css("transform","none");else if(3==getUrlVar().paper){$(".sheet").addClass("hide"),$(".sheet#palitraPaper").removeClass("hide");var c=$(".sheet#palitraPaper").clone();c=c.get(0).outerHTML,$(".allsheet").append(c)}else if(30==getUrlVar().paper){$(".sheet").addClass("hide"),$(".sheet#palitraPaper").removeClass("hide");var c=$(".sheet#palitraPaper").clone()}else if(4==getUrlVar().paper)$(".sheet").addClass("hide"),$(".sheet#timetablePaper").removeClass("hide");else if(50==getUrlVar().paper)$(".sheet").addClass("hide"),$(".sheet#envelope").removeClass("hide"),$(".sheet#envelope .front").addClass("hidden"),$(".sheet#envelope .back").removeClass("hidden").css("transform","none").css("overflow","initial"),$(".sheet#envelope .sheetview").css("marginTop","168px");else if(5==getUrlVar().paper)$(".sheet").addClass("hide"),$(".sheet#envelope").removeClass("hide"),$(".sheet#envelope .back").addClass("hidden"),$(".sheet#envelope .front").removeClass("hidden").css("transform","none");else if(51==getUrlVar().paper){$(".sheet").addClass("hide"),$(".sheet#envelope").removeClass("hide"),$(".sheet#envelope .back").addClass("hidden"),$(".sheet#envelope .front").removeClass("hidden").css("left","1.5%").css("top","172%").addClass("envelope51"),$(".envelope_canvas").css("transform","rotate(315deg) scale(1.47)"),$(".sheet#envelope .front, .sheet#envelope .plate_box, .sheet#envelope .element6").css("overflow","initial"),$(".sheet#envelope .front").clone(!0).appendTo(".allsheet").addClass("envelope_A4").removeAttr("style").removeClass("front"),$(".envelope_A4 [elemplace=envelopePattern]").html("<div></div>"),"cover"==$(".envelope_A4 [elemplace=envelopePattern]").css("background-size")?$(".sheet#envelope .front [elemplace=envelopeBg], .envelope_A4 [elemplace=envelopePattern]").css("background","none"):$(".sheet#envelope .front [elemplace=envelopeBg], .sheet#envelope .front [elemplace=envelopePattern]").css("background","none"),$(".allsheet").css("marginTop","-250px"),$(".envelope_A4").css("background","none");var d=$(".envelope_A4 [elemplace=envelopeBg]").css("background-image");$(".envelope_A4").css("background-image",d);var p=$(".envelope_A4 [elemplace=envelopeBg]").css("background-size");$(".envelope_A4").css("background-size",p);var h=$(".envelope_A4 [elemplace=envelopeBg]").css("background-color");$(".envelope_A4").css("background-color",h)}else if(52==getUrlVar().paper){$(".sheet").addClass("hide"),$(".sheet#envelope .front").clone(!0).appendTo(".allsheet").addClass("envelope_A4").removeAttr("style").removeClass("front"),$(".envelope_A4 [elemplace=envelopePattern]").html('<div class="envelope_cutting"></div>');var d=$(".sheet#envelope .back [elemplace=envelopeInBg]").css("background-image");$(".envelope_A4 [elemplace=envelopeBg]").css("background-image",d);var p=$(".sheet#envelope .back [elemplace=envelopeInBg]").css("background-size");$(".envelope_A4 [elemplace=envelopeBg]").css("background-size",1.47*p.slice(0,-2)+"px");var h=$(".sheet#envelope .back [elemplace=envelopeInBg]").css("background-color");$(".envelope_A4 [elemplace=envelopeBg]").css("background-color",h);var m=$(".sheet#envelope .back [elemplace=envelopeInPattern]").css("background-image");$(".envelope_A4 [elemplace=envelopePattern]").css("background-image",m);var g=$(".sheet#envelope .back [elemplace=envelopeInPattern]").css("backgroundSize");$(".envelope_A4 [elemplace=envelopePattern]").css("backgroundSize",g),$(".envelope_A4 .envelope_cutting").css("transform","rotateY(180deg)")}else if(777==getUrlVar().paper)getUrlVar().bg&&$("body").css("background","#"+getUrlVar().bg),$(".sheet").addClass("hide"),$(".allsheet .sheet").length<2&&(contentHTML=$(".content").html(),$(".content").html('<div class="allsheet" textplace="module_text" style="margin-top: 0px;">'+contentHTML+"</div>"),$(".allsheet .sheet").attr("id","mainInv")),$("body").css("transform","scale(0.75)").css("overflow","hidden"),$(".allsheet").append('<div class="screenshot_wood"></div>'),i=getUrlVar().style_id?"template/invent/?style_id="+getUrlVar().style_id+"&screenshot=1&mode=mobile_preview":"template/invent/?user="+e+"&screenshot=1&mode=mobile_preview",$(".allsheet").prepend('<div class="screenshot_iphone screenshoter"><div class="domain"><strong>my-domain.ru</strong></div><div class="iFrame" style="-webkit-transform-origin-x: 0;"><div class="brow"></div><iframe style="border:0px;"  width = "100%" height = "100%" src = "'+window.location.origin+"/"+i+'"></iframe></div><div class="secretButton phoneBtn"></div><div class="upButton phoneBtn"></div><div class="downButton phoneBtn"></div></div>'),$(".iFrame").css("-webkit-transform:","scale(0.95)"),getUrlVar().user&&t.domain&&$(".screenshot_iphone .domain strong").text(t.domain),$(".sheet#mainInv").removeClass("hide").css("position","absolute"),$(".sheet#mainInv").addClass("screenshot_mainInv").css("transform","rotate(0deg)"),$(".sheet#mainInv .front").removeClass("hidden").addClass("screenshoter").css("transform","rotate(0deg)").css("z-index",1).addClass("clickTo").attr("to","/cabinet/constructor/paper"),$(".sheet#mainInv .back").removeClass("hidden").addClass("screenshoter").addClass("screenshot_mainInv").addClass("screenshot_mainInv_back").css("transform","rotate(0deg)").css("z-index",0).css("backface-visibility","inherit").addClass("clickTo").attr("to","/cabinet/constructor/paper#sheet2"),$(".sheet#palitraPaper").removeClass("hide").addClass("screenshoter").addClass("screenshot_palitraPaper").css("transform","rotate(0deg)").addClass("clickTo").attr("to","/cabinet/constructor/paper#palitraPaper_control"),$(".sheet#timetablePaper").removeClass("hide").addClass("screenshoter").addClass("screenshot_timetablePaper").css("transform","rotate(0deg)").addClass("clickTo").attr("to","/cabinet/constructor/paper#timetablePaper_control"),$(".sheet#envelope .front").removeClass("hidden").css("transform","rotateY(0deg)"),$(".sheet#envelope").addClass("screenshoter").removeClass("hide").addClass("screenshot_envelope").addClass("clickTo").attr("to","/cabinet/constructor/paper#envelope_control"),$("*").is(".sheet#envelope [action=envelope_text1]")&&(fontSize=$(".sheet#envelope [action=envelope_text1]").css("fontSize").slice(0,-2),$(".sheet#envelope [action=envelope_text1]").css("fontSize",1.416*fontSize)),$("*").is(".sheet#envelope [action=envelope_text2]")&&(fontSize=$(".sheet#envelope [action=envelope_text2]").css("fontSize").slice(0,-2),$(".sheet#envelope [action=envelope_text2]").css("fontSize",1.416*fontSize)),$("*").is(".sheet#envelope [action=envelope_text3]")&&(fontSize=$(".sheet#envelope [action=envelope_text3]").css("fontSize").slice(0,-2),$(".sheet#envelope [action=envelope_text3]").css("fontSize",1.416*fontSize)),$(".sheet#envelope .back").addClass("hidden"),$(".sheet#mainInv .back .background").prepend("<div class=plate_box></div>"),$(".plate_box").css("background-size","cover").css("background-position-y","center").addClass("gradient_shadow"),$("#envelope .plate_box").addClass("gradient_shadow");else if(999==getUrlVar().paper)$(".sheet").addClass("hide"),$(".allsheet .sheet").length<2&&(contentHTML=$(".content").html(),$(".content").html('<div class="allsheet" textplace="module_text" style="margin-top: 0px;">'+contentHTML+"</div>"),$(".allsheet .sheet").attr("id","mainInv")),$(".allsheet .sheet").length<7&&$(".allsheet").html('<a to="/cabinet/constructor/paper/#seatingCard_control" class="clickTo getTableCardonFinish">Сгенерируйте комплекты карточек для банкета, перейдя на страницу конструктора.<br><a>Перейти в конструктор</a></a>'),$("body").css("transform","scale(0.75)").css("overflow","hidden"),$(".allsheet").append('<div class="screenshot_seating"></div><div class="clips_seating"></div><div class="spoon_seating"></div>'),$(".sheet#tableCard").removeClass("hide").addClass("screenshoter").addClass("screenshot_tableCard").css("transform","rotate(2deg) scale(0.8)").addClass("clickTo").attr("to","/cabinet/constructor/paper#tableCard_control"),$(".sheet#seatingCard").removeClass("hide").addClass("screenshoter").addClass("screenshot_seatingCard").css("transform","rotate(2deg) scale(0.9)").addClass("clickTo").attr("to","/cabinet/constructor/paper#seatingCard_control"),$(".sheet#seatingPlan").removeClass("hide").addClass("screenshoter").addClass("screenshot_seatingPlan").css("transform","rotate(2deg) scale(0.96)").addClass("clickTo").attr("to","/cabinet/constructor/paper#seatingPlan_control"),1==getUrlVar().iframe&&($(".sheet#seatingPlan").css("right","-90px"),$(".sheet#seatingCard").css("left","161px")),$(".sheet#seatingCard .textLine").text("Иванов Иван"),$(".sheet#seatingPlan [action=seatingplan_text]").text("Иванов Иван<br>Иванов Сергей<br>Сергеева Ольга<br>Романов Мирон<br>Миронова Анна<br>Антонов Семен<br>"),$(".plate_box").css("background-size","cover").css("background-position-y","center"),$("#seatingCard .plate_box, #tableCard .plate_box").addClass("gradient_shadow");else if(9==getUrlVar().paper)$("body").css("background","none"),$(".sheet").addClass("hide"),$(".sheet#seatingPlan").removeClass("hide"),$(".sheet#seatingPlan .sheetview").css("margin-top","0px"),getUrlVar().table?tbl=getUrlVar().table:tbl=1,$(".element_plan [action=seatingplan_number]").text(tbl),$(".element_plan").css("top","2%"),$.ajax({url:window.location.origin+"/template/invent/userinvent.php",data:{Action:"seatingPlan",table:tbl,user:e},type:"post",success:function(e){blocks=JSON.parse(e),$.each(blocks,function(e,t){"block1"==e?$("#seatingPlan [action=seatingplan_text]").html(nl2br(t)):"block2"==e&&""!=t&&($("#seatingPlan [action=seatingplan_text]").clone(!0).addClass("Block2").html(nl2br(t)).appendTo($("#seatingPlan [action=seatingplan_text]").parent()),$("#seatingPlan [action=seatingplan_text]").parent().addClass("plan2block"))})}});else if(91==getUrlVar().paper){$("#seatingCard .textLine").html(nl2br(t.guest_name)),$("body").css("background","none"),$(".sheet").addClass("hide"),$(".sheet#seatingCard").removeClass("hide").css("border-bottom","1px solid #ccc").css("border-top","1px solid #ccc"),$(".sheet#seatingCard .sheetview").css("margin-top","0px");var c=$(".sheet#seatingCard").clone().addClass("oborot");c=c.get(0).outerHTML,$(".allsheet").prepend(c),$(".oborot").css("transform","rotate(180deg)").css("border","0px solid #ccc"),$(".oborot .textLine").css("top",$(".oborot .textLine").get(0).style.top.slice(0,-1)-1+9+"%")}else if(92==getUrlVar().paper)$("body").css("background","#fff"),$(".sheet").addClass("hide"),$(".sheet#timetablePaper").removeClass("hide").html('<div style="-webkit-transform-origin-x: 0; -webkit-transform: scale(1.00); height:100%; width:100%"><iframe style="border:0px;"  width = "100%" height = "100%" src = "'+window.location.origin+"/template/invent/?user="+e+"&screenshot=1&opros_result=1&guest="+guest_id+'&print=1"></iframe></div>');else if(93==getUrlVar().paper){$("body").css("background","none"),$(".sheet").addClass("hide"),getUrlVar().table?tbl=getUrlVar().table:tbl=1,$(".element_tcard [action=tablecard_number]").text(tbl),$(".element_tcard").css("top","2%"),$(".sheet#tableCard").removeClass("hide"),$(".sheet#tableCard .sheetview").css("margin-top","0px");var c=$(".sheet#tableCard").clone().addClass("oborot");c=c.get(0).outerHTML,$(".allsheet").prepend(c),$(".oborot").css("transform","scale(1.0) rotate(180deg)").css("border","0px solid #ccc"),$(".oborot h2").css("top",$(".oborot h2").get(0).style.top.slice(0,-1)-1+9+"%")}else 6==getUrlVar().paper?($("body").css("background","none"),$(".sheet").addClass("hide"),$(".dazzle").css("height","0%"),$(".allsheet").prepend('<div class="screenshot_iphone_only"><div class="iFrame" style="-webkit-transform-origin-x: 0;"><iframe style="border:0px;" scrolling="no"  width = "408px" height = "723px" src = "'+window.location.origin+"/template/invent/?user="+e+'&screenshot=1"></iframe></div></div>')):888==getUrlVar().paper&&($(".sheet").addClass("hide"),$("body").css("background","none"),$("body").css("transform","scale(0.9)").css("overflow","hidden"),$(".dazzle").css("height","0%"),$(".allsheet").append('<div class="screenshot_wood"></div>'),1==getUrlVar().wood&&$(".screenshot_wood").css("background-image","url(/src/img/finish_fon.jpg)"),$(".allsheet").prepend('<div class="screenshot_iphone screenshoter"><div class="domain"><strong>my-domain.ru</strong></div><div class="iFrame" style="-webkit-transform-origin-x: 0;"><div class="brow"></div><iframe style="border:0px;"  width = "100%" height = "100%" src = "'+window.location.origin+"/"+i+'"></iframe></div><div class="secretButton phoneBtn"></div><div class="upButton phoneBtn"></div><div class="downButton phoneBtn"></div></div>'),$(".screenshot_iphone").css("-webkit-transform","rotate(0deg) scale(0.9)"),$(".sheet#mainInv").removeClass("hide").css("position","absolute"),$(".sheet#mainInv").addClass("screenshot_mainInv").css("transform","rotate(1deg)"),$(".sheet#mainInv .front").removeClass("hidden").addClass("screenshoter").css("transform","rotate(0deg)").css("z-index",1),$(".sheet#mainInv .back").removeClass("hidden").addClass("screenshoter").addClass("screenshot_mainInv").addClass("screenshot_mainInv_back").css("transform","rotate(7deg)").css("z-index",0).css("backface-visibility","inherit"),$(".sheet#palitraPaper").removeClass("hide").addClass("screenshoter").addClass("screenshot_palitraPaper").css("transform","rotate(4deg)"),$(".sheet#timetablePaper").removeClass("hide").addClass("screenshoter").addClass("screenshot_timetablePaper").css("transform","rotate(-4deg)"),$(".sheet#envelope .front").removeClass("hidden").css("transform","rotate(0deg)"),$(".sheet#envelope").addClass("screenshoter").removeClass("hide").addClass("screenshot_envelope").css("width","518px").css("height","365px").css("transform","rotate(0deg)"),fontSize=$(".sheet#envelope [action=envelope_text1]").css("fontSize").slice(0,-2),$(".sheet#envelope [action=envelope_text1]").css("fontSize",1.416*fontSize),fontSize=$(".sheet#envelope [action=envelope_text2]").css("fontSize").slice(0,-2),$(".sheet#envelope [action=envelope_text2]").css("fontSize",1.416*fontSize),fontSize=$(".sheet#envelope [action=envelope_text3]").css("fontSize").slice(0,-2),$(".sheet#envelope [action=envelope_text3]").css("fontSize",1.416*fontSize),$(".sheet#envelope .back").addClass("hidden"),$(".sheet#mainInv .back .background").prepend("<div class=plate_box></div>"),$(".plate_box").css("background-size","cover").css("background-position-y","center"),$("#envelope .plate_box").addClass("gradient_shadow"));if($(".content").html($(".content #screen").html()),getUrlVar().paper||$(".content").css("overflow","hidden"),getUrlVar().style_id||t.pay_id||getUrlVar().screenshot&&0!=getUrlVar().screenshot)var v=0;else{$(".dazzle").css("height","100%");var v=1}if(t.pay_id&&($.cookie("user_type","buyer",{path:"/"}),$(".dazzle").css("height","0%")),$(".atc_event").addClass("hide"),$(".atcb-list").addClass("hide"),getUrlVar().opros_result){var u=$("#opros").clone();u=u.get(0).outerHTML,$(".content").addClass("oprosPage").html(u),$("#opros").fadeIn(),$(".alert-warning").addClass("hide"),$(".header_opros").removeClass("hide"),$(".goSummary a").attr("href","?user="+e+"&opros_result=1"),$("#opros").css("max-width","1128px"),$.ajax({url:window.location.origin+"/template/invent/userinvent.php",data:{Action:"getResultOpros",guest:guest_id,user:e},type:"post",success:function(t){console.log(t),t=JSON.parse(t),$(".goLeft a").attr("href","?user="+e+"&opros_result=1&guest="+t.prev_guest.id),$(".goRight a").attr("href","?user="+e+"&opros_result=1&guest="+t.next_guest.id),guest_id||$.each(t.opros,function(e,t){0==t.count?isgrey="grey":isgrey="",0==t.percent?isnone="hide":isnone="",$("#weddingOpros [for="+e+"]").append(' <div class="point '+isgrey+'">'+t.count+'</div><div class="per '+isnone+'">'+t.percent+"%</div>")})}})}if(getUrlVar().show_comment){var f=$(".commentYes").removeClass("hide").clone();return f=f.get(0).outerHTML,$(".content").html(f),$(".editComment").remove(),""==$(".commentFromGuest span").text()&&$(".commentFromGuest span").text("Комментария от гостя пока нет"),$(".commentYes .time").text(""),$(".commentYes").css("max-width","1128px").css("margin","20px"),$(".andGift").hasClass("hide")||$(".content").append('<div class="disclamer"><div class=icon><i class="fa fa-question-circle"></i></div>Обратите внимание, что денежная транзакция проводится ЮМани (ex Яндекс.Деньгами) (ПАО Сбербанк), поэтому мы ничего не знаем об его успешности и завершенности, а лишь отображаем выбор гостя, который планировал перевод.</div>'),!1}if(t.palitra||v||$("#palitra").addClass("hide"),t.eorder&&($(".content [hideOrder]").removeClass("hide"),$(".content [hideOrder*="+t.eorder+"]").addClass("hide")),getUrlVar().opros_result||("eAllSMSOrder"==t.eorder||"eAllOrder"==t.eorder?$("#opros").remove():$("#opros").css("display","none")),$("#map").html(""),$(".module").css("border","0px solid #fff"),$(".hoverborder").css("border","0px solid rgba(0, 0, 0, 0)"),getUrlVar().admin||$("palitra_text, text_opros, btn_agree, comment, wedding_timetable").removeAttr("contenteditable"),$(".textLine").each(function(e,t){$(this).removeAttr("contenteditable"),str=$(this).html(),str=str.replace(/&gt;/g,">"),str=str.replace(/&lt;/g,"<"),str=makeHotwords(str,a),str=makeSexWords(str,a.sex),$(this).html(str)}),t.guest_agree&&($(".guestAgree[answer=1]").addClass("hide"),$(".iAgree").removeClass("hide"),$(".cancelLink").removeClass("hide"),$(".acceptLink").addClass("hide"),1==$(".guestAgree[answer=1]").attr("data-opros")&&($("#opros").fadeIn(),$("#screen").scrollTo("#opros"))),t.guest_opros&&(answer=t.guest_opros.split(", "),$.each(answer,function(e,t){$("label[for="+t+"] i").addClass("fa-check-circle").removeClass("fa-circle-o"),$("input[id="+t+"]").attr("checked","checked")})),getUrlVar().print)if(t.guest_opros){var b=$(".header_opros .name b").text();$(".header_opros").remove(),$("#screen #opros").css("background","#fff"),$("#screen").css("background","#fff"),$("#opros #weddingOpros [name=question], #opros #weddingOpros [name=variants]").css("color","#000"),$("#opros #weddingOpros .fa-check-circle").parent().addClass("noHide"),$("#opros #weddingOpros [action=varianttxt] label:not(.noHide)").remove(),$("#opros #weddingOpros").attr("style","transform: scale(0.6); width: 170%; margin-left: -35%; margin-top: -26%; line-height: 0.6;"),$("body").css("background","#fff"),$("#opros #weddingOpros").prepend('<b style="color:#888"><i style="font-weight: normal; text-align: right; display: block; color: #ccc">Создано на weddingpost.ru</i>Ответы на опрос<h3 style="color:#000">'+b+"</h3></b>");
}else $("#screen").html("");if(JSON.parse(t.userdata).timing.city&&(addr=JSON.parse(t.userdata).timing.city+" "+JSON.parse(t.userdata).timing.address),JSON.parse(t.userdata).timing.coord_x&&JSON.parse(t.userdata).timing.coord_y&&"underfined"!=JSON.parse(t.userdata).timing.coord_y&&"underfined"!=JSON.parse(t.userdata).timing.coord_x&&(user_coord=JSON.parse(t.userdata).timing.coord_x+","+JSON.parse(t.userdata).timing.coord_y),JSON.parse(t.userdata).timing.date){var C=JSON.parse(t.userdata).timing.datecheck;if("wednow"==C)$(".weddatecontent").addClass("hide"),$(".countdown").removeClass("wedyet").addClass("wednow").html($(".now.weddatecontent").html());else if(C)$(".weddatecontent").addClass("hide"),$(".yet.weddatecontent b strong").text(Math.round(C)),$(".countdown").removeClass("wednow").addClass("wedyet").html($(".yet.weddatecontent").html());else{var x=JSON.parse(t.userdata).timing.date;$(".weddingdate").html(x),arr_weddate=x.split(".");var _=$(".count.weddatecontent").html();$(".countdown").countdown(arr_weddate[2]+"/"+arr_weddate[1]+"/"+arr_weddate[0],function(e){$(this).html(e.strftime(_))})}}getUrlVar().screenshot||$(".addtocalendar a").attr("href","userinventd7d2.html?Action=getCal&amp;guest="+guest_id+"&user_id="+e)}})}if($(window).load(function(){}),"undefined"==typeof getUrlVar().mydomain&&(window.location.origin.indexOf("weddingpost.ru")+1!=0||window.location.origin.indexOf("localhost")+1))if("undefined"!=typeof getUrlVar().user||getUrlVar().style_id)var user_id=getUrlVar().user,guest_id=getUrlVar().guest;else{var path=document.location.pathname.match(/\/[^\D]+/g),user_id=path[0].slice(1);if(path[1])var guest_id=path[1].slice(1);else var guest_id=1}else if(!(window.location.origin.indexOf("localhost")+1)){"undefined"!=typeof getUrlVar().mydomain?mydomain=getUrlVar().mydomain:mydomain=window.location.hostname;var user_id;if($.ajax({url:window.location.origin+"/template/invent/userinvent.php",data:{Action:"getIDbyDomain",mydomain:mydomain},type:"post",async:!1,success:function(e){e?user_id=e:window.location.href="https://weddingpost.ru/404.html"}}),document.location.pathname.length>1)var path=document.location.pathname.match(/\/[^\D]+/g),guest_id=path[0].slice(1)}var user_coord="";$(document).ready(function(){$("#screen").on("click",".acceptLink",function(){return $(".guestAgree[answer=1]").click(),!0}),$("#screen").on("click",".cancelLink",function(){return $(".guestAgree[answer=0]").click(),!0}),$("#screen").on("click",".dropdownMenubox [module*=comment]",function(){return $(".addComment").click(),!0}),$("#screen").on("click",".addComment",function(){$(".addComment").css("visibility","hidden"),$(".commentBox").fadeIn()}),$("#screen").on("keyup",".commentBox textarea",function(){autoTextarea(this,2)}),$("#screen").on("click",".selectedMoney",function(){$(".moneyBox").addClass("open")}),$("#screen").on("click",".sendComment",function(){var e=$(".commentBox textarea").val();if(e){if(!guest_id)return toastr.info("Сообщение отправляется на персональных страницах приглашений гостей"),!1;var t=$(".moneyBox:not(.hide) a span").text(),s=0;$(".moneyBox").hasClass("hide")||(s=$(".moneyList a.oneMoney.active").attr("val"));var a={money:s,moneyText:t,text:e,time:new Date};$.ajax({url:window.location.origin+"/template/invent/userinvent.php",data:{Action:"saveComment",guest:guest_id,comment:JSON.stringify(a)},type:"post",success:function(s){var a=$("[var=guest]").text();toastr.success("Спасибо, ваш ответ сохранен"),showComment(a,e,t)}})}else $(".commentBox textarea").addClass("errorInput1px")}),$("#screen").on("click",".editComment",function(){$(".commentBox").removeClass("hide"),$(".commentYes").addClass("hide"),$(".commentBox textarea").val(br2nl($(".commentYes .commentFromGuest span").html())).change().keyup();var e=$(".andGift div").text();$(".selectedMoney span").text(e);var t=e.replace(/ /g,"").slice(0,-3);$(".moneyList .oneMoney").removeClass("active"),$(".moneyList .oneMoney[val="+t+"]").addClass("active"),$(".withMoney").addClass("stopSendMoney"),$(".commentYes .andGift").hasClass("hide")||$("input[name=withMoney").is(":checked")||$("input[name=withMoney]").click()}),$("#screen").on("click",".moneyList a.oneMoney",function(){$(".moneyList a").removeClass("active"),$(this).addClass("active");var e=$(this).attr("val");$(this).parent().parent().children(".selectedMoney").children("a").children("span").text($(this).text());var t=$(".withMoney").attr("link");$(".sendComment").attr("href",t+e).attr("target","_blank"),$(".withMoney").removeClass("stopSendMoney")}),$("#screen").on("click",".menuNav",function(){$(".dropdownMenubox").toggleClass("hide"),$(".menuNavIcon").toggleClass("fa-bars"),$(".menuNavIcon").toggleClass("fa-times")}),$("#screen").on("change","input[name=withMoney]",function(){if($(this).is(":checked")){var e=$(" .moneyList a.active").attr("val"),t=$(".withMoney").attr("link");$(".withMoney").hasClass("stopSendMoney")||$(".sendComment").attr("href",t+e).attr("target","_blank"),$(".moneyBox").removeClass("hide")}else $(".sendComment").removeAttr("href").removeAttr("target"),$(".moneyBox").addClass("hide")}),$("body").on("click",'[href*="#"]',function(e){var t=60;$("html,body").stop().animate({scrollTop:$(this.hash).offset().top-t},1e3),e.preventDefault()}),$("#screen").on("click",".form-check-input",function(){if(guest_id&&!getUrlVar().opros_result){opros=$(this).parent("div").parent("div").parent("div").attr("data-opros"),idi=$(this).attr("id"),$(this).prop("checked")?$("label[for="+idi+"] i").addClass("fa-check-circle").removeClass("fa-circle-o"):$("label[for="+idi+"] i").removeClass("fa-check-circle").addClass("fa-circle-o");var e="";$(".opros div div label").children("i.fa-check-circle").each(function(t,s){quest=$(s).parent("label").attr("for"),e=e?e+", "+quest:e=quest}),$.ajax({url:window.location.origin+"/template/invent/userinvent.php",data:{Action:"guestOpros",guest:guest_id,content:e},type:"post",success:function(e){guest=$("[var=guest]").text(),313==user_id?toastr.success("Спасибо, ваш ответ сохранен и отправлен Ярославу и родителям"):toastr.success("Спасибо, ваш ответ сохранен и отправлен организатору")}})}else toastr.info("Ответы опроса выбираются и сохраняются только на персонализированной странице гостя")});var e=getUrlVar().paper;e?getInvs(user_id,guest_id,"paper"):getInvs(user_id,guest_id,"electro"),$("#screen").on("click",".guestAgree",function(){answer=$(this).attr("answer"),acceptInvite(answer)}),$(".atc_event").addClass("hide")});