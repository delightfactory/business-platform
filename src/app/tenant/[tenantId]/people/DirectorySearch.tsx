'use client';

import Form from 'next/form';
import { Button, Icon } from '@/components/ui';
import { useEffect, useRef } from 'react';
import { useFormStatus } from 'react-dom';

export function DirectorySearch({ href, query, page }: { href: string; query: string; page: number }) {
  const form = useRef<HTMLFormElement>(null);
  const input = useRef<HTMLInputElement>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const composing = useRef(false);
  const submitted = useRef<{ query: string; raw: string } | null>(null);
  const applied = useRef({ query, page });

  function cancelScheduledSearch() {
    if (timer.current !== null) clearTimeout(timer.current);
    timer.current = null;
  }

  function scheduleSearch() {
    cancelScheduledSearch();
    if (composing.current || !input.current) return;
    if (input.current.value.trim() === query) return;
    timer.current = setTimeout(() => {
      timer.current = null;
      form.current?.requestSubmit();
    }, 400);
  }

  useEffect(() => {
    const unchanged = applied.current.query === query && Object.is(applied.current.page, page);
    applied.current = { query, page };
    const field = input.current;
    if (!field) return;
    if (unchanged) {
      if (field.value.trim() !== query && !composing.current) {
        if (timer.current !== null) clearTimeout(timer.current);
        timer.current = setTimeout(() => {
          timer.current = null;
          form.current?.requestSubmit();
        }, 400);
      }
      return;
    }
    const ownResult = submitted.current?.query === query;
    if (!ownResult || field.value === submitted.current?.raw) field.value = query;
    else if (field.value.trim() !== query && !composing.current) {
      if (timer.current !== null) clearTimeout(timer.current);
      timer.current = setTimeout(() => {
        timer.current = null;
        form.current?.requestSubmit();
      }, 400);
    }
  }, [query, page]);

  useEffect(() => {
    function restoreFromHistory() {
      if (timer.current !== null) clearTimeout(timer.current);
      timer.current = null;
      submitted.current = null;
      if (input.current) input.current.value = new URL(window.location.href).searchParams.get('q')?.trim() ?? '';
    }
    window.addEventListener('popstate', restoreFromHistory);
    return () => {
      if (timer.current !== null) clearTimeout(timer.current);
      window.removeEventListener('popstate', restoreFromHistory);
    };
  }, []);

  return <Form ref={form} action={href} replace scroll={false} prefetch={false} role="search" className="people-search-form"
    onSubmit={(event) => {
      cancelScheduledSearch();
      if (composing.current) {
        event.preventDefault();
        return;
      }
      if (input.current) submitted.current = { query: input.current.value.trim(), raw: input.current.value };
    }}>
    <label htmlFor="people-query">ابحث بالاسم أو رمز الموظف</label>
    <div><Icon name="search" size={19} /><input ref={input} id="people-query" name="q" type="search" maxLength={100} defaultValue={query}
      placeholder="ابحث بالاسم أو الرمز" onChange={scheduleSearch}
      onCompositionStart={() => { composing.current = true; cancelScheduledSearch(); }}
      onCompositionEnd={() => { composing.current = false; scheduleSearch(); }} />
      <SearchAction />
    </div>
    <SearchStatus />
  </Form>;
}

function SearchAction() {
  const { pending } = useFormStatus();
  return <Button variant="ghost" type="submit" aria-busy={pending}>بحث</Button>;
}

function SearchStatus() {
  const { pending } = useFormStatus();
  return <p className="field-hint" role="status" aria-live="polite">
    {pending ? 'جارٍ تحديث النتائج؛ القائمة الحالية تخص آخر بحث مكتمل.' : ''}
  </p>;
}
