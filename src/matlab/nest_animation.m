function nest_animation(G, p, ax, recorder)
% NEST_ANIMATION 三阶段鸟巢动画（含生长/延展）
%   G:          几何数据（来自 nest_geometry）
%   p:          参数字典（含视觉/动画参数）
%   ax:         axes 句柄
%   recorder:   VideoWriter 句柄（可选，为空时仅实时显示）

% 阶段 0：空坐标系
title(ax, '');
cla(ax); hold(ax, 'on');
view(ax, [p.az, p.el]); axis(ax, 'equal');
xlim(ax, [-p.a-1, p.a+1]); ylim(ax, [-p.b-1, p.b+1]); zlim(ax, [-2*p.c, 2*p.c]);
xlabel(ax, 'x'); ylabel(ax, 'y'); zlabel(ax, 'z');
grid(ax, 'on'); box(ax, 'on');

% 椭圆地面环
ell = G.ellipse_pts;
plot3(ax, ell(1,:), ell(2,:), zeros(1,200), 'Color', [0.5 0.5 0.5]);
drawnow; pause(p.hold_t);

% 阶段 1：立柱生长
title(ax, '\color{black}阶段1：立柱升起');

pillar_h = gobjects(1, p.N);
for i = 1:p.N
    pillar_h(i) = plot3(ax, [G.pillars(1,i) G.pillars(1,i)], ...
                            [G.pillars(2,i) G.pillars(2,i)], ...
                            [0 0], ...
                            'Color', [0 114 189]/255, 'LineWidth', 2);
end

for i = 1:p.N
    z_target = G.pillars(3,i);
    for frm = 1:p.n_pillar
        t = frm / p.n_pillar;
        set(pillar_h(i), 'ZData', [0, t * z_target]);
        drawnow;
        if ~isempty(recorder)
            writeVideo(recorder, getframe(ax.Parent));
        end
    end
    pause(p.dt);  % 每根完成后停顿
end

% 阶段 2：曲面片 + 母线
title(ax, '\color{black}阶段2：直线构成曲面');
pause(p.hold_t * 0.5);

% 半透明曲面片
surf(ax, G.surf_mesh.X, G.surf_mesh.Y, G.surf_mesh.Z, ...
    'FaceAlpha', p.alpha_surf, 'EdgeColor', 'none', ...
    'FaceColor', [237 177 32]/255);
drawnow;

% u=const 组母线（#EDB120）
rule_uh = gobjects(1, length(G.rule_u));
for k = 1:length(G.rule_u)
    d = G.rule_u{k};
    % 零长初态（起点=终点在参数负端），避免「先全出现再消失」
    rule_uh(k) = plot3(ax, [d(1,1) d(1,1)], [d(2,1) d(2,1)], [d(3,1) d(3,1)], ...
        'Color', [237 177 32]/255, 'LineWidth', 1.5);
end
drawnow;  % 刷新隐藏零长线

for k = 1:length(G.rule_u)
    d = G.rule_u{k};
    xs = d(1,1); ys = d(2,1); zs = d(3,1);
    xe = d(1,2); ye = d(2,2); ze = d(3,2);
    for frm = 1:p.n_rule
        t = frm / p.n_rule;
        set(rule_uh(k), ...
            'XData', [xs, xs + t*(xe-xs)], ...
            'YData', [ys, ys + t*(ye-ys)], ...
            'ZData', [zs, zs + t*(ze-zs)]);
        drawnow;
        if ~isempty(recorder)
            writeVideo(recorder, getframe(ax.Parent));
        end
    end
    pause(p.dt);
end

% v=const 组母线（#FFD060）
rule_vh = gobjects(1, length(G.rule_v));
for k = 1:length(G.rule_v)
    d = G.rule_v{k};
    rule_vh(k) = plot3(ax, [d(1,1) d(1,1)], [d(2,1) d(2,1)], [d(3,1) d(3,1)], ...
        'Color', [255 208 96]/255, 'LineWidth', 1.5);
end
drawnow;

for k = 1:length(G.rule_v)
    d = G.rule_v{k};
    xs = d(1,1); ys = d(2,1); zs = d(3,1);
    xe = d(1,2); ye = d(2,2); ze = d(3,2);
    for frm = 1:p.n_rule
        t = frm / p.n_rule;
        set(rule_vh(k), ...
            'XData', [xs, xs + t*(xe-xs)], ...
            'YData', [ys, ys + t*(ye-ys)], ...
            'ZData', [zs, zs + t*(ze-zs)]);
        drawnow;
        if ~isempty(recorder)
            writeVideo(recorder, getframe(ax.Parent));
        end
    end
    pause(p.dt);
end

% 终态停留
pause(1.5);
end
