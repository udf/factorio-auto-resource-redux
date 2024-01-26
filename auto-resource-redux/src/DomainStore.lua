local DomainStore = {}

function DomainStore.get_domain_key(entity)
  return string.format("%d-%s", entity.surface.index, entity.force.name)
end

function DomainStore.get_subdomain(domain_key, subdomain_key, default_fn)
  local domain = global.domains[domain_key]
  if domain == nil then
    domain = {}
    global.domains[domain_key] = domain
  end
  local subdomain = domain[subdomain_key]
  if subdomain == nil then
    subdomain = default_fn(domain_key)
    domain[subdomain_key] = subdomain
  end
  return subdomain
end

function DomainStore.initialise()
  if global.domains == nil then
    global.domains = {}
  end
end

return DomainStore