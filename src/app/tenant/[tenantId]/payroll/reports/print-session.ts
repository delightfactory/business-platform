// Presentation guard for supported browser printing; not protection against
// screenshots, devtools or copying financial values already authorized on screen.
export function startPayslipPrint(root:HTMLElement,host:Window):()=>void{
 let firstPrint=true,closed=false;
 const before=()=>{if(!firstPrint)root.removeAttribute('data-print-authorized');firstPrint=false;};
 const clear=()=>{if(closed)return;closed=true;root.removeAttribute('data-print-authorized');host.removeEventListener('beforeprint',before);host.removeEventListener('afterprint',clear);host.clearTimeout(timer);};
 root.setAttribute('data-print-authorized','true');
 host.addEventListener('beforeprint',before);host.addEventListener('afterprint',clear);
 const timer=host.setTimeout(clear,60000);
 try{host.print();}catch(error){clear();throw error;}
 return clear;
}
