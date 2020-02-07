function cs_queue=CS_env_queue()
% get cs env vars or set defaults for
%  CS_GATEKEEPER_QUEUE:slow_master
%  CS_FULL_VOLUME_QUEUE:high_priority
%% queue support
cs_queue.gatekeeper = getenv('CS_GATEKEEPER_QUEUE');
if isempty(cs_queue.gatekeeper)
    cs_queue.gatekeeper =  'slow_master';%'high_priority';
    setenv('CS_GATEKEEPER_QUEUE',cs_queue.gatekeeper)
end
cs_queue.full_volume = getenv('CS_FULL_VOLUME_QUEUE');
if isempty(cs_queue.full_volume)
    cs_queue.full_volume = 'high_priority';
    setenv('CS_FULL_VOLUME_QUEUE',cs_queue.full_volume)
end
cs_queue.recon = getenv('CS_RECON_QUEUE');
if isempty(cs_queue.recon)
    cs_queue.recon = 'matlab';
    setenv('CS_RECON_QUEUE',cs_queue.recon)
end