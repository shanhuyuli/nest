% TEST_NEST_GEOMETRY 验证 nest_geometry 几何计算正确性（迭代2）
% 运行: run('test_nest_geometry')
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    fprintf('=== nest_geometry Unit Tests (Iteration 2) ===\n');
    passed = 0;  failed = 0;

    hpZ = @(x,y) 18*(x.^2/6400 - y.^2/5184) + 23.2;

    % ---- Test 1: HP surface height ----
    fprintf('\nTest 1: hyperboloidZ values\n');
    if abs(hpZ(60,0) - 33.325) < 0.01
        passed = passed + 1;  fprintf('  PASS: z at (60,0)\n');
    else, failed = failed + 1;  fprintf('  FAIL: z at (60,0)\n'); end
    if abs(hpZ(0,53.5) - 13.263) < 0.01
        passed = passed + 1;  fprintf('  PASS: z at (0,53.5)\n');
    else, failed = failed + 1;  fprintf('  FAIL: z at (0,53.5)\n'); end

    % ---- Test 2: line-ellipse intersection ----
    fprintf('\nTest 2: lineEllipseIntersect\n');
    pts = lineEllipseIntersect(0, 0, 60, 53.5);
    if size(pts,1) == 2
        passed = passed + 1;  fprintf('  PASS: 2 intersections\n');
    else, failed = failed + 1;  fprintf('  FAIL: %d intersections\n', size(pts,1)); end
    if isempty(lineEllipseIntersect(0, 100, 60, 53.5))
        passed = passed + 1;  fprintf('  PASS: far line 0 intersections\n');
    else, failed = failed + 1;  fprintf('  FAIL: far line had intersections\n'); end

    % ---- Test 3: ruling midpoints on HP surface ----
    fprintf('\nTest 3: ruling midpoints on HP surface\n');
    G = nest_geometry([]);
    max_err = 0;
    for i = 1:length(G.roof_segments)
        seg = G.roof_segments{i};
        mx = (seg(1,1)+seg(2,1))/2;  my = (seg(1,2)+seg(2,2))/2;
        mz = (seg(1,3)+seg(2,3))/2;
        max_err = max(max_err, abs(mz - hpZ(mx, my)));
    end
    if max_err < 1e-10
        passed = passed + 1;  fprintf('  PASS: max err=%.2e\n', max_err);
    else, failed = failed + 1;  fprintf('  FAIL: max err=%.2e\n', max_err); end

    % ---- Test 4: pillar tops on HP surface + min height ----
    fprintf('\nTest 4: pillar properties\n');
    min_z = inf;  max_pillar_err = 0;
    for i = 1:size(G.pillars,1)
        x = G.pillars(i,1);  y = G.pillars(i,2);  zt = G.pillars(i,4);
        max_pillar_err = max(max_pillar_err, abs(zt - hpZ(x, y)));
        min_z = min(min_z, zt);
    end
    if max_pillar_err < 1e-10
        passed = passed + 1;  fprintf('  PASS: pillar err=%.2e\n', max_pillar_err);
    else, failed = failed + 1;  fprintf('  FAIL: pillar err=%.2e\n', max_pillar_err); end
    if min_z >= 13
        passed = passed + 1;  fprintf('  PASS: min height=%.1f\n', min_z);
    else, failed = failed + 1;  fprintf('  FAIL: min height=%.1f < 13\n', min_z); end

    % ---- Summary ----
    fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
    if failed > 0, error('TESTS FAILED'); end

%% LOCAL FUNCTIONS (mirrors nest_geometry for test independence)
function pts = lineEllipseIntersect(m, d, a_ell, b_ell)
    A = 1/a_ell^2 + m^2/b_ell^2;
    B = 2*m*d/b_ell^2;
    Cc = d^2/b_ell^2 - 1;
    disc = B^2 - 4*A*Cc;
    if disc < 0, pts = [];
    elseif disc < 1e-12, x = -B/(2*A); pts = [x, m*x+d];
    else
        x1 = (-B + sqrt(disc))/(2*A); x2 = (-B - sqrt(disc))/(2*A);
        pts = [x1, m*x1+d; x2, m*x2+d];
    end
end
