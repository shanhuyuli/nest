function run_nest_demo(varargin)
% RUN_NEST_DEMO 运行鸟巢双曲抛物面动画
%
% 用法:
%   run_nest_demo                          % 实时动画（不录制）
%   run_nest_demo('record', true)          % 录制 mp4
%   run_nest_demo('record', true, 'gif', true)  % 录制 mp4 + gif
%   run_nest_demo('record', true, 'out', 'custom.mp4')
%
% 名称-值对参数:
%   'record'  - false(默认) | true    是否录制 mp4
%   'gif'     - false(默认) | true    是否导出 gif
%   'out'     - 输出路径（默认 'out/nest.mp4'）
%   'params'  - 参数字典结构体（覆盖默认值）

% 解析参数
opts = parse_args(varargin{:});

% 构建默认参数
p = struct(...
    'a', 6, 'b', 5, 'c', 2.5, 'N', 10, ...
    'M_u', 9, 'M_v', 9, ...
    'az', -35, 'el', 30, ...
    'n_pillar', 8, 'n_rule', 10, ...
    'dt', 0.15, 'hold_t', 0.8, ...
    'fps', 30, 'alpha_surf', 0.2);

% 覆盖用户参数
if isfield(opts, 'params') && isstruct(opts.params)
    fns = fieldnames(opts.params);
    for i = 1:length(fns)
        p.(fns{i}) = opts.params.(fns{i});
    end
end

% 计算几何
G = nest_geometry(p);

% 创建图窗
fig = figure('Color', 'w', 'Position', [100 100 900 700], 'Visible', 'on');
ax = axes(fig);

% 录制逻辑
if opts.record
    mp4_path = opts.out;
    [mp4_dir, ~] = fileparts(mp4_path);
    if ~exist(mp4_dir, 'dir'), mkdir(mp4_dir); end
    
    vw = VideoWriter(mp4_path, 'MPEG-4');
    vw.FrameRate = p.fps;
    open(vw);
    nest_animation(G, p, ax, vw);
    close(vw);
    fprintf('mp4 已导出: %s\n', mp4_path);
    
    if opts.gif
        gif_path = [mp4_path(1:end-4) '.gif'];
        mp4_to_gif(mp4_path, gif_path, p.fps);
        fprintf('gif 已导出: %s\n', gif_path);
    end
else
    nest_animation(G, p, ax, []);
end
end

function opts = parse_args(varargin)
    opts = struct('record', false, 'gif', false, 'out', 'out/nest.mp4');
    i = 1;
    while i <= length(varargin)
        if i+1 <= length(varargin) && ischar(varargin{i})
            switch lower(varargin{i})
                case 'record'
                    opts.record = logical(varargin{i+1}); i = i+2;
                case 'gif'
                    opts.gif = logical(varargin{i+1}); i = i+2;
                case 'out'
                    opts.out = varargin{i+1}; i = i+2;
                case 'params'
                    opts.params = varargin{i+1}; i = i+2;
                otherwise
                    i = i+1;
            end
        else
            i = i+1;
        end
    end
end

function mp4_to_gif(mp4_path, gif_path, fps)
% MP4_TO_GIF 从 mp4 文件逐帧读取并转为 gif
    vr = VideoReader(mp4_path);
    delay = 1 / fps;
    first = true;
    while hasFrame(vr)
        frame = readFrame(vr);
        [im, map] = rgb2ind(frame, 256, 'nodither');
        if first
            imwrite(im, map, gif_path, 'gif', 'LoopCount', Inf, 'DelayTime', delay);
            first = false;
        else
            imwrite(im, map, gif_path, 'gif', 'WriteMode', 'append', 'DelayTime', delay);
        end
    end
end
