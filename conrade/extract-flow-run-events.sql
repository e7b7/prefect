with stuff as (
    select
        occurred,
        split_part(resource_id, '.', 2) as run_type,
        resource -> 'prefect.resource.name' as name,
        resource -> 'prefect.state-type' as state
    from events
)
select *
from stuff
where run_type = 'flow-run';
