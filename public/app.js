document.addEventListener('DOMContentLoaded',()=>{
  document.querySelectorAll('.nav a').forEach(a=>{if(a.href===location.href||a.href.includes(location.search))a.classList.add('active')})
  document.querySelectorAll('form').forEach(form=>{form.addEventListener('submit',e=>{if(form.dataset.submitting==='1'){e.preventDefault();return false}form.dataset.submitting='1';const btn=form.querySelector('button[type="submit"],button:not([type])');if(btn){btn.dataset.text=btn.textContent;btn.textContent='处理中...';btn.style.opacity='.75';btn.disabled=true}})})
  const msg=document.querySelector('.alert');
  if(msg){const t=document.createElement('div');t.className='toast show';t.textContent=msg.textContent;document.body.appendChild(t);setTimeout(()=>t.classList.remove('show'),2600)}
  const clock=document.getElementById('home-clock');
  if(clock){
    let base=Number(clock.dataset.serverTs||0)*1000;
    let started=Date.now();
    const pad=n=>String(n).padStart(2,'0');
    const render=()=>{
      const d=new Date(base+(Date.now()-started));
      clock.textContent=`${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
    };
    render();setInterval(render,1000);
  }

});