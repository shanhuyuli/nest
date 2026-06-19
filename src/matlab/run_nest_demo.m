function run_nest_demo(record)
% RUN_NEST_DEMO 运行鸟巢双曲抛物面动画
%   run_nest_demo          % 实时动画
%   run_nest_demo(true)    % 录制 mp4

if nargin < 1, record = false; end

% 计算几何
G = nest_geometry([]);

% 创建图窗
fig = figure('Color', 'w', 'Position', [100 100 900 700]);
ax = axes(fig);

% 运行动画
nest_animation(G, ax, record, 18);
end
