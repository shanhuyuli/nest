function nest_animation(G, ax, record_mode, fps)
% NEST_ANIMATION 三阶段鸟巢动画（含生长/延展过渡）
%   G:           几何数据（来自 nest_geometry）
%   ax:          axes 句柄
%   record_mode: false(实时) | true(录制mp4)
%   fps:         帧率 (默认18)

if nargin < 4, fps = 18; end
if nargin < 3, record_mode = false; end

dt_grow = 0.03;     % 每根立柱生长间隔 (s)
dt_rule = 0.05;     % 每条屋顶线铺出间隔 (s)
hold_t  = 0.8;      % 阶段间停顿 (s)
final_t = 2.0;      % 终态停留 (s)

vw = [];  % VideoWriter handle, set below if recording

% ===== 录制初始化（必须在 Stage 0 之前）=====
if record_mode
    if ~exist('out', 'dir'), mkdir('out'); end
    vw = VideoWriter('out/nest.mp4', 'MPEG-4');
    vw.FrameRate = fps;
    open(vw);
end

% ===== 辅助函数 =====
    function writeFrame()
        drawnow;
        if record_mode, writeVideo(vw, getframe(ax.Parent)); end
    end
    function pauseFrame(duration)
        if record_mode
            for j = 1:round(duration * fps)
                writeVideo(vw, getframe(ax.Parent));
            end
        else
            pause(duration);
        end
    end

% ===== Stage 0: 空坐标系 =====
cla(ax); hold(ax, 'on');
view(ax, [-20, 25]);
daspect(ax, [1 1 1]);
xlim(ax, [-65, 65]);  ylim(ax, [-58, 58]);  zlim(ax, [0, 38]);
xlabel(ax, 'X');  ylabel(ax, 'Y');  zlabel(ax, 'Z');
grid(ax, 'on');

plot3(ax, G.ellipse_outer(1,:), G.ellipse_outer(2,:), zeros(1,200), ...
    'Color', [0.5 0.5 0.5], 'LineStyle', '--', 'LineWidth', 1);
plot3(ax, G.ellipse_inner(1,:), G.ellipse_inner(2,:), zeros(1,200), ...
    'Color', [0.5 0.5 0.5], 'LineStyle', ':', 'LineWidth', 1);
title(ax, 'Stage 0: Coordinate System');
writeFrame();
pauseFrame(hold_t);

% ===== Transition 0->1: 立柱逐根生长 =====
title(ax, 'Stage 1: Pillars Rising');

Npillars = size(G.pillars, 1);
pillar_h = gobjects(Npillars, 1);
for i = 1:Npillars
    pillar_h(i) = plot3(ax, ...
        [G.pillars(i,1) G.pillars(i,1)], ...
        [G.pillars(i,2) G.pillars(i,2)], ...
        [0 0], 'Color', [0.75 0.75 0.75], 'LineWidth', 3);
end

for i = 1:Npillars
    z_target = G.pillars(i,4);
    n_frames = max(1, round(dt_grow * fps));
    for fr = 1:n_frames
        t = fr / n_frames;
        set(pillar_h(i), 'ZData', [0, t * z_target]);
        writeFrame();
    end
end
pauseFrame(hold_t);

% ===== Transition 1->2: 屋顶线逐条铺出 =====
title(ax, 'Stage 2: Rulings Appear');

Nsegments = length(G.roof_segments);
roof_h = gobjects(Nsegments, 1);
for i = 1:Nsegments
    seg = G.roof_segments{i};
    roof_h(i) = plot3(ax, [seg(1,1) seg(1,1)], [seg(1,2) seg(1,2)], ...
        [seg(1,3) seg(1,3)], 'Color', [0.93 0.69 0.13], 'LineWidth', 2);
end

for i = 1:Nsegments
    seg = G.roof_segments{i};
    n_frames = max(1, round(dt_rule * fps));
    for fr = 1:n_frames
        t = fr / n_frames;
        set(roof_h(i), ...
            'XData', [seg(1,1), seg(1,1) + t*(seg(2,1)-seg(1,1))], ...
            'YData', [seg(1,2), seg(1,2) + t*(seg(2,2)-seg(1,2))], ...
            'ZData', [seg(1,3), seg(1,3) + t*(seg(2,3)-seg(1,3))]);
        writeFrame();
    end
end

title(ax, 'Bird Nest: Hyperbolic Paraboloid Ruled Surface');
pauseFrame(final_t);

% ===== 清理录制 =====
if record_mode
    close(vw);
    fprintf('MP4 exported: out/nest.mp4\n');
end

end
