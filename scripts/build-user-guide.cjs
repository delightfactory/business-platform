'use strict';
// Offline, dependency-free rendering of the project's trusted training Markdown.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),source=path.join(root,'docs/user-guide/ar.md'),target=path.join(root,'public/user-guide.html');
const markdown=fs.readFileSync(source,'utf8').replace(/^\uFEFF/,'').replace(/\r\n/g,'\n');
const escape=s=>s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
const { icon, paragraphClass, diagram, masthead } = require('./user-guide-design.cjs');
const inline=s=>escape(s).replace(/\*\*(.+?)\*\*/g,'<strong>$1</strong>').replace(/`([^`]+)`/g,'<bdi dir="ltr">$1</bdi>').replace(/\bUTF-8\b/g,'<bdi class="guide-token" dir="ltr">UTF-8</bdi>');
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
const flush=()=>{if(paragraph.length){const text=paragraph.join(' '),style=paragraphClass(text);parts.push(style?'<p class="guide-callout '+style[0]+'">'+icon(style[1])+'<span>'+inline(text)+'</span></p>':'<p>'+inline(text)+'</p>');paragraph=[];}};
const closeList=()=>{if(list){parts.push('</'+list+'>');list=null;}};
for(let i=0;i<lines.length;i++){
 const line=lines[i].trim();
 const task=/^<!-- guide: ([a-z -]+) -->$/.exec(line);
 if(task){flush();closeList();if(inTask)throw new Error('Nested guide task');parts.push(`<div data-guide-task="${task[1]}">`);inTask=true;continue;}
 if(line==='<!-- /guide -->'){flush();closeList();if(!inTask)throw new Error('Unmatched guide task');parts.push('</div>');inTask=false;continue;}

 if(!line){flush();closeList();continue;}
 const heading=/^(#{1,4})\s+(.+)$/.exec(line);
 if(heading){flush();closeList();const level=heading[1].length,id='section-'+(++section);if(level===2){if(!inSection)parts.push('</div>');if(inTask)throw new Error('Unclosed guide task before chapter');if(inSection)parts.push('</section>');inSection=true;const number=Number(/^(\d+)\./.exec(heading[2])?.[1]||0),topic=number?topicFor(number):heading[2].startsWith('صفحة اعتماد')?'company-users':'common';toc.push({id,text:heading[2],topic});parts.push(`<section data-guide-topic="${topic}">`);}parts.push(`<h${level} id="${id}">${inline(heading[2])}</h${level}>`);if(level===2){const chapter=Number(/^(\d+)\./.exec(heading[2])?.[1]||0);const illustration=diagram(chapter);if(illustration){const topics={8:"people-import",14:"self-attendance",19:"self-leave"};parts.push(`<div data-guide-task="${topics[chapter]}">${illustration}</div>`);}}continue;}
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
const html=`<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><title>دليل استخدام المنصة والموارد البشرية</title><style>${fs.readFileSync(path.join(root,'public/user-guide.css'),'utf8')}</style></head><body><a class="skip" href="#guide">انتقل إلى الدليل</a>${masthead()}<section class="guide-tools" id="guide-tools" aria-label="اختيار محتوى الدليل"><div class="guide-fields"><div class="guide-field"><label for="guide-role">الدليل المناسب لمهمتك</label><select id="guide-role"><option value="personal">مهامي حسب صلاحياتي</option><option value="employee">الموظف</option><option value="company">مسؤول الشركة</option><option value="people">الموارد البشرية</option><option value="attendance">مسؤول الحضور</option><option value="leave">مسؤول الإجازات</option><option value="payroll">مسؤول الرواتب</option><option value="advances">السلف</option><option value="reports">التقارير</option><option value="operator">مشغّل المنصة</option><option value="all">الدليل الكامل للتدريب</option></select></div><div class="guide-field"><label for="guide-search">ابحث عن مهمة أو شاشة</label><input id="guide-search" type="search" placeholder="مثال: إضافة موظف أو تسجيل دفعة" autocomplete="off" aria-controls="guide"></div><button id="guide-clear" type="button" hidden>مسح البحث</button></div><p id="guide-status" class="guide-status" role="status" aria-live="polite" aria-atomic="true"></p><p id="guide-partial" hidden>تعذر التحقق من بعض مهام حسابك الآن. افتح الدليل مجددًا من حسابك بعد إعادة المحاولة، أو اختر المهمة يدويًا؛ هذا لا يعني سحب صلاحياتك.</p><p>ابدأ من المهمة في الفهرس. عرض الشرح لا يمنح صلاحية تنفيذ الإجراء؛ تتحدد الأزرار والبيانات من حسابك وخدمات شركتك.</p></section><main><nav aria-label="فهرس دليل الاستخدام"><strong>انتقل إلى القسم</strong>${toc.map(x=>`<a data-guide-topic="${x.topic}" href="#${x.id}">${inline(x.text)}</a>`).join('')}</nav><article id="guide"><p id="guide-empty" hidden>لا توجد أقسام تطابق بحثك ضمن هذا العرض. جرّب كلمة أخرى، أو امسح البحث، أو اختر الدليل الكامل للتدريب.</p>${parts.join('\n')}</article></main><footer class="guide-footer">نسخة تدريب الشركات — 16 أكتوبر 2026 · دليل عام بلا بيانات عملاء أو حسابات دخول. · البحث والتصفية داخل الدليل فقط.</footer><script>${fs.readFileSync(path.join(root,'public/user-guide-filter.js'),'utf8')}</script></body></html>`;
fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,html);console.log(JSON.stringify({source:'docs/user-guide/ar.md',output:'public/user-guide.html',sections:toc.length,bytes:Buffer.byteLength(html)}));
