function run_nest_demo(record)
if nargin < 1, record = false; end
G = nest_geometry([]);
fig = figure('Color','w','Position',[100 100 900 700]);
ax = axes(fig);
nest_animation(G, ax, record, 18);
end
