function nest_animation(G, ax, record_mode, fps)
% NEST_ANIMATION 三阶段鸟巢动画 (Iteration 2)
if nargin < 4, fps = 18; end
if nargin < 3, record_mode = false; end
dt_grow = 0.05; dt_rule = 0.05; hold_t = 0.8; final_t = 2.0; vw = [];
fig = ax.Parent;  % capture figure handle

if record_mode
    if ~exist('out','dir'), mkdir('out'); end
    vw = VideoWriter('out/nest.mp4','MPEG-4'); vw.FrameRate = fps; open(vw);
end
    function wf()
        drawnow; if record_mode, writeVideo(vw, getframe(fig)); end
    end
    function pf(d)
        if record_mode, for j=1:round(d*fps), writeVideo(vw,getframe(fig)); end
        else, pause(d); end
    end

% Stage 0
cla(ax); hold(ax,'on'); view(ax,[-20 25]); daspect(ax,[1 1 1]);
xlim(ax,[-65 65]); ylim(ax,[-58 58]); zlim(ax,[0 38]);
xlabel(ax,'X'); ylabel(ax,'Y'); zlabel(ax,'Z'); grid(ax,'on');
plot3(ax,G.ellipse_outer(1,:),G.ellipse_outer(2,:),zeros(1,200),'Color',[0.5 0.5 0.5],'LineStyle','--');
plot3(ax,G.ellipse_inner(1,:),G.ellipse_inner(2,:),zeros(1,200),'Color',[0.5 0.5 0.5],'LineStyle',':');
title(ax,'Stage 0: Coordinate System'); wf(); pf(hold_t);

	% Transition 0->1: pillars grow (sorted by x, left-to-right, batch per frame for 5s total)
	title(ax,'Stage 1: Pillars Rising');
	Np = size(G.pillars,1);
	[~, sort_idx] = sort(G.pillars(:,1));  % sort by x-coordinate
	total_pillar_frames = round(5 * fps);  % 5 seconds
	batch_size = max(1, ceil(Np / total_pillar_frames));
	ph = gobjects(Np,1);
	for i=1:Np, ph(i)=plot3(ax,[G.pillars(i,1) G.pillars(i,1)],[G.pillars(i,2) G.pillars(i,2)],[0 0],'Color',[0.75 0.75 0.75],'LineWidth',3); end
	si = 1;
	while si <= Np
	    batch_end = min(Np, si + batch_size - 1);
	    for fr = 1:2  % 2 sub-frames for smooth growth
	        t = fr / 2;
	        for k = si:batch_end
	            i = sort_idx(k);  zt = G.pillars(i,4);
	            set(ph(i), 'ZData', [0, t * zt]);
	        end
	        wf();
	    end
	    si = batch_end + 1;
	end
	pf(hold_t);

% Transition 1->2: roof extend
title(ax,'Stage 2: Rulings Appear');
Ns = length(G.roof_segments); rh = gobjects(Ns,1);
for i=1:Ns
    s=G.roof_segments{i}; rh(i)=plot3(ax,[s(1,1) s(1,1)],[s(1,2) s(1,2)],[s(1,3) s(1,3)],'Color',[0.93 0.69 0.13],'LineWidth',2);
end
for i=1:Ns
    s=G.roof_segments{i}; nf=max(1,round(dt_rule*fps));
    for fr=1:nf, t=fr/nf;
        set(rh(i),'XData',[s(1,1) s(1,1)+t*(s(2,1)-s(1,1))],'YData',[s(1,2) s(1,2)+t*(s(2,2)-s(1,2))],'ZData',[s(1,3) s(1,3)+t*(s(2,3)-s(1,3))]); wf();
    end
end
title(ax,'Bird Nest: HP Ruled Surface'); pf(final_t);
if record_mode, close(vw); fprintf('MP4: out/nest.mp4\n'); end
end
