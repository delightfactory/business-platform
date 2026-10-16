'use strict';
// Offline, dependency-free rendering of the project's trusted training Markdown.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),source=path.join(root,'docs/user-guide/ar.md'),target=path.join(root,'public/user-guide.html');
const markdown=fs.readFileSync(source,'utf8').replace(/^\uFEFF/,'').replace(/\r\n/g,'\n');
const escape=s=>s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
const inline=s=>escape(s).replace(/\*\*(.+?)\*\*/g,'<strong>$1</strong>').replace(/`([^`]+)`/g,'<bdi>$1</bdi>');
const chapterTopics = {
  1: 'common', 2: 'common', 3: 'common',
  4: 'company-users company-structure people-manage payroll-configure',
  5: 'company-users', 6: 'company-branding company-structure people-org',
  7: 'people-view people-manage people-employment people-compensation', 8: 'people-import',
  9: 'people-manage people-employment company-users', 10: 'people-employment people-compensation', 11: 'work-policies',
  12: 'attendance-sources', 13: 'attendance-sources attendance-review',
  14: 'profile self-attendance', 15: 'attendance-input attendance-review',
  16: 'attendance-view attendance-review', 17: 'leave-manage', 18: 'leave-balances',
  19: 'self-leave', 20: 'leave-view leave-manage leave-approve',
  21: 'payroll-view payroll-prepare payroll-configure payroll-approve payroll-close payroll-payments',
  22: 'payroll-prepare payroll-configure', 23: 'payroll-prepare payroll-configure',
  24: 'payroll-view payroll-prepare payroll-approve', 25: 'payroll-view payroll-approve payroll-close',
  26: 'payroll-reports', 27: 'advances', 28: 'payroll-payments', 29: 'payroll-correct',
  30: 'common', 31: 'common',
  32: 'operator-companies operator-invitations operator-commercial operator-lifecycle operator-team operator-statutory',
};
const topicFor = number => chapterTopics[number] || 'common';
const lines=markdown.split('\n'),parts=['<div data-guide-intro>'],toc=[];let section=0,list=null,paragraph=[],inSection=false,inTask=false;
const flush=()=>{if(paragraph.length){parts.push('<p>'+inline(paragraph.join(' '))+'</p>');paragraph=[];}};
const closeList=()=>{if(list){parts.push('</'+list+'>');list=null;}};
for(let i=0;i<lines.length;i++){
 const line=lines[i].trim();
 const task=/^<!-- guide: ([a-z -]+) -->$/.exec(line);
 if(task){flush();closeList();if(inTask)throw new Error('Nested guide task');parts.push(`<div data-guide-task="${task[1]}">`);inTask=true;continue;}
 if(line==='<!-- /guide -->'){flush();closeList();if(!inTask)throw new Error('Unmatched guide task');parts.push('</div>');inTask=false;continue;}

 if(!line){flush();closeList();continue;}
 const heading=/^(#{1,4})\s+(.+)$/.exec(line);
 if(heading){flush();closeList();const level=heading[1].length,id='section-'+(++section);if(level===2){if(!inSection)parts.push('</div>');if(inTask)throw new Error('Unclosed guide task before chapter');if(inSection)parts.push('</section>');inSection=true;const number=Number(/^(\d+)\./.exec(heading[2])?.[1]||0),topic=number?topicFor(number):heading[2].startsWith('صفحة اعتماد')?'company-users':'common';toc.push({id,text:heading[2],topic});parts.push(`<section data-guide-topic="${topic}">`);}parts.push(`<h${level} id="${id}">${inline(heading[2])}</h${level}>`);continue;}
 if(/^---+$/.test(line)){flush();closeList();parts.push('<hr>');continue;}
 if(line.startsWith('|')&&i+1<lines.length&&/^\|[\s:|-]+\|$/.test(lines[i+1].trim())){
  flush();closeList();const cells=s=>s.replace(/^\||\|$/g,'').split('|').map(x=>x.trim());
  parts.push('<div class="table-wrap"><table><thead><tr>'+cells(line).map(c=>'<th>'+inline(c)+'</th>').join('')+'</tr></thead><tbody>');i++;
  while(i+1<lines.length&&lines[i+1].trim().startsWith('|')){i++;parts.push('<tr>'+cells(lines[i].trim()).map(c=>'<td>'+inline(c)+'</td>').join('')+'</tr>');}
  parts.push('</tbody></table></div>');continue;
 }
 const bullet=/^([-*]|\d+[.)])\s+(.+)$/.exec(line);
 if(bullet){flush();const kind=/^\d/.test(bullet[1])?'ol':'ul';if(list!==kind){closeList();parts.push('<'+kind+'>');list=kind;}parts.push('<li>'+inline(bullet[2])+'</li>');continue;}
 closeList();paragraph.push(line);
}
flush();closeList();if(inTask)throw new Error('Unclosed guide task at end');if(inSection)parts.push('</section>');
const html=`<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><title>دليل استخدام المنصة والموارد البشرية</title><style>
*{box-sizing:border-box}body{margin:0;background:#f3f5f8;color:#172b3a;font:16px/1.95 Tahoma,Arial,sans-serif}a{color:#116d71;text-decoration:none}a:hover{text-decoration:underline}header{background:#123c46;color:white;padding:32px max(24px,calc((100vw - 1100px)/2));}header p{margin:0 0 14px}header a,header button{display:inline-block;border:1px solid #dce8e8;border-radius:8px;background:#fff;color:#123c46;padding:9px 16px;font:inherit;cursor:pointer;margin:4px}main{display:grid;grid-template-columns:260px minmax(0,800px);gap:24px;max-width:1140px;margin:24px auto;padding:0 20px}nav{align-self:start;position:sticky;top:16px;background:#fff;border:1px solid #dce2e7;border-radius:12px;padding:16px;max-height:90vh;overflow:auto;font-size:13px}nav a{display:block;padding:5px 0}article{background:#fff;border:1px solid #dce2e7;border-radius:12px;padding:32px;min-width:0}h1{font-size:28px;line-height:1.6;margin:0 0 20px}h2{font-size:22px;color:#116d71;border-bottom:1px solid #dce2e7;padding-bottom:10px;margin-top:40px;scroll-margin-top:20px}h3{font-size:18px;margin-top:26px}h4{font-size:16px}p{margin:12px 0}li{padding-inline-start:4px;margin:6px 0}hr{border:0;border-top:1px solid #e1e6eb;margin:28px 0}.table-wrap{max-width:100%;overflow:auto}table{border-collapse:collapse;width:100%;font-size:13px}th,td{border:1px solid #dce2e7;padding:9px 12px;text-align:right;vertical-align:top}th{background:#eef5f5}bdi{direction:ltr;unicode-bidi:isolate}footer{text-align:center;color:#586875;padding:24px;font-size:13px}.skip{position:absolute;top:-100px}.skip:focus{top:0;background:white;padding:10px;z-index:2}
@media(max-width:850px){main{display:block;padding:0 12px}nav{position:static;max-height:280px;margin-bottom:16px}article{padding:20px}header{padding:24px 16px}}
@page{size:A4;margin:17mm 15mm 19mm} @media print{body{background:white;font-size:10.5pt;line-height:1.85}header,nav,.skip,footer{display:none}main{display:block;margin:0;padding:0;max-width:none}article{border:0;border-radius:0;padding:0}h1{font-size:24pt}h2{font-size:17pt;margin-top:22pt;break-before:auto}h3{font-size:13pt}h1,h2,h3,h4{break-after:avoid}p,li{orphans:3;widows:3}tr{break-inside:avoid}table{font-size:9pt}.table-wrap{overflow:visible}thead{display:table-header-group}a{color:inherit}hr{margin:16pt 0}}
[hidden]{display:none!important}.guide-tools{max-width:1140px;margin:24px auto;padding:20px;background:white;border:1px solid #dce2e7;border-radius:12px}.guide-tools label{font-weight:700}.guide-tools input{font:inherit;max-width:100%;width:320px;padding:8px;margin:8px;border:1px solid #71838b;border-radius:8px;min-height:44px}.guide-tools select{font:inherit;max-width:100%;padding:8px;margin:8px;border:1px solid #71838b;border-radius:8px;min-height:44px}.guide-tools p{margin:6px 0}.guide-tools a{display:inline-block;min-height:44px;padding:6px}.guide-tools button{font:inherit;min-height:44px;cursor:pointer}#guide-clear{border:1px solid #b6c4ca;border-radius:8px;background:#fff;color:#244951;padding:8px 14px}#guide-clear:hover{background:#eef5f5}#guide-clear:focus-visible{outline:2px solid #116d71;outline-offset:3px}.guide-intro{max-width:75ch}.guide-status{color:#244951}@media(max-width:850px){.guide-tools{margin:12px}.guide-tools select,.guide-tools input{display:block;margin-inline:0;width:100%}}@media print{.guide-tools{display:none}} </style></head><body><a class="skip" href="#guide">انتقل إلى الدليل</a><header><p><strong>دليل الشركة للتدريب والاستخدام اليومي</strong><br>اختر مهمتك من الفهرس. الأمثلة توضيحية؛ سياسات الشركة والصلاحيات هي المرجع.</p><button type="button" onclick="window.print()">طباعة الأقسام المعروضة أو حفظها PDF</button><a href="user-guide.pdf" download>تنزيل الدليل الكامل PDF</a></header><section class="guide-tools" aria-label="اختيار محتوى الدليل"><label for="guide-role">الدليل المناسب لمهمتك</label><select id="guide-role"><option value="personal">مهامي حسب صلاحياتي</option><option value="employee">الموظف</option><option value="company">مسؤول الشركة</option><option value="people">الموارد البشرية</option><option value="attendance">مسؤول الحضور</option><option value="leave">مسؤول الإجازات</option><option value="payroll">مسؤول الرواتب</option><option value="advances">السلف</option><option value="reports">التقارير</option><option value="operator">مشغّل المنصة</option><option value="all">الدليل الكامل للتدريب</option></select><label for="guide-search">ابحث عن مهمة أو شاشة</label><input id="guide-search" type="search" placeholder="مثال: إضافة موظف أو تسجيل دفعة" autocomplete="off" aria-controls="guide"><button id="guide-clear" type="button" hidden>مسح البحث</button><p id="guide-status" class="guide-status" role="status" aria-live="polite" aria-atomic="true"></p><p id="guide-partial" hidden>تعذر التحقق من بعض مهام حسابك الآن. افتح الدليل مجددًا من حسابك بعد إعادة المحاولة، أو اختر المهمة يدويًا؛ هذا لا يعني سحب صلاحياتك.</p><p>ابدأ من المهمة في الفهرس. عرض الشرح لا يمنح صلاحية تنفيذ الإجراء؛ تتحدد الأزرار والبيانات من حسابك وخدمات شركتك.</p></section><main><nav aria-label="فهرس دليل الاستخدام"><strong>انتقل إلى القسم</strong>${toc.map(x=>`<a data-guide-topic="${x.topic}" href="#${x.id}">${inline(x.text)}</a>`).join('')}</nav><article id="guide"><p id="guide-empty" hidden>لا توجد أقسام تطابق بحثك ضمن هذا العرض. جرّب كلمة أخرى، أو امسح البحث، أو اختر الدليل الكامل للتدريب.</p>${parts.join('\n')}</article></main><footer>نسخة تدريب الشركات — 16 أكتوبر 2026 · دليل عام بلا بيانات عملاء أو حسابات دخول. · البحث والتصفية داخل الدليل فقط.</footer><script>${fs.readFileSync(path.join(root,'public/user-guide-filter.js'),'utf8')}</script></body></html>`;
fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,html);console.log(JSON.stringify({source:'docs/user-guide/ar.md',output:'public/user-guide.html',sections:toc.length,bytes:Buffer.byteLength(html)}));
