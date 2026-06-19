%% test_nest_geometry — 鸟巢几何单元测试套件
% 运行: runtests('test_nest_geometry')
% 验证: 7 项测试覆盖母线是直线、立柱位置/高度、参数边界

function tests = test_nest_geometry
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testCase.TestData.p = struct('a',6,'b',5,'c',2.5,'N',10,'M_u',9,'M_v',9);
    testCase.TestData.G = nest_geometry(testCase.TestData.p);
end

%% TC1: 母线中点在曲面上（证明线段是直线）
function testRulingMidpointOnSurface(testCase)
    G = testCase.TestData.G;
    p = testCase.TestData.p;
    hpz = @(x,y) p.c*(x.^2/p.a^2 - y.^2/p.b^2);
    
    for k = 1:length(G.rule_u)
        d = G.rule_u{k};
        M = (d(:,1) + d(:,2)) / 2;
        z_expected = hpz(M(1), M(2));
        verifyEqual(testCase, M(3), z_expected, 'AbsTol', 1e-10);
    end
    for k = 1:length(G.rule_v)
        d = G.rule_v{k};
        M = (d(:,1) + d(:,2)) / 2;
        z_expected = hpz(M(1), M(2));
        verifyEqual(testCase, M(3), z_expected, 'AbsTol', 1e-10);
    end
end

%% TC2: 立柱在椭圆上
function testPillarsOnEllipse(testCase)
    G = testCase.TestData.G;
    p = testCase.TestData.p;
    for i = 1:p.N
        r = (G.pillars(1,i)/p.a)^2 + (G.pillars(2,i)/p.b)^2;
        verifyEqual(testCase, r, 1, 'AbsTol', 1e-10);
    end
end

%% TC3: 柱顶贴合曲面
function testPillarTopOnSurface(testCase)
    G = testCase.TestData.G;
    p = testCase.TestData.p;
    hpz = @(x,y) p.c*(x.^2/p.a^2 - y.^2/p.b^2);
    for i = 1:p.N
        z_expected = hpz(G.pillars(1,i), G.pillars(2,i));
        verifyEqual(testCase, G.pillars(3,i), z_expected, 'AbsTol', 1e-10);
    end
end

%% TC4: u=const 母线全段在曲面上（取 t=0.25, 0.75 插值点）
function testRulingU_FullOnSurface(testCase)
    G = testCase.TestData.G;
    p = testCase.TestData.p;
    hpz = @(x,y) p.c*(x.^2/p.a^2 - y.^2/p.b^2);
    for k = 1:length(G.rule_u)
        d = G.rule_u{k};
        for t = [0.25, 0.75]
            P = d(:,1) + t * (d(:,2) - d(:,1));
            z_expected = hpz(P(1), P(2));
            verifyEqual(testCase, P(3), z_expected, 'AbsTol', 1e-10);
        end
    end
end

%% TC5: v=const 母线全段在曲面上
function testRulingV_FullOnSurface(testCase)
    G = testCase.TestData.G;
    p = testCase.TestData.p;
    hpz = @(x,y) p.c*(x.^2/p.a^2 - y.^2/p.b^2);
    for k = 1:length(G.rule_v)
        d = G.rule_v{k};
        for t = [0.25, 0.75]
            P = d(:,1) + t * (d(:,2) - d(:,1));
            z_expected = hpz(P(1), P(2));
            verifyEqual(testCase, P(3), z_expected, 'AbsTol', 1e-10);
        end
    end
end

%% TC6: 非法参数抛错
function testInvalidParams(testCase)
    verifyError(testCase, @() nest_geometry(struct('a',6,'b',5,'c',2.5,'N',2,'M_u',9,'M_v',9)), 'NEST:pillarCount');
    verifyError(testCase, @() nest_geometry(struct('a',0,'b',5,'c',2.5,'N',10,'M_u',9,'M_v',9)), 'NEST:ellipseAxis');
    verifyError(testCase, @() nest_geometry(struct('a',6,'b',5,'c',-1,'N',10,'M_u',9,'M_v',9)), 'NEST:param');
end

%% TC7: 曲面网格覆盖椭圆域
function testSurfMeshCoversDomain(testCase)
    G = testCase.TestData.G;
    p = testCase.TestData.p;
    verifyTrue(testCase, min(G.surf_mesh.X(:)) <= -p.a + 0.1);
    verifyTrue(testCase, max(G.surf_mesh.X(:)) >=  p.a - 0.1);
    verifyTrue(testCase, min(G.surf_mesh.Y(:)) <= -p.b + 0.1);
    verifyTrue(testCase, max(G.surf_mesh.Y(:)) >=  p.b - 0.1);
end
