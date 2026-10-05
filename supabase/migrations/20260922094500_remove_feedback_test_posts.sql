-- Remove only the synthetic records created by Catch's backend verification.
delete from public.feedback
where id in (
  '5f571375-1a90-45d6-972b-93a774c6e4e8'::uuid,
  '513bfa36-20a7-4705-99d9-fbc5ab56bbf7'::uuid,
  'fc2efb18-c5d2-4b04-96b3-771cf376440d'::uuid,
  '1ffa330a-db51-4ff7-9c1d-ad8adcb28631'::uuid
);
