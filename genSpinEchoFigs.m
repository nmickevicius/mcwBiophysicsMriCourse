
gb = 42.58e6; 

% assume a 90-degree RF pulse along +x has left us with the following
% magnetization vector immediately after the RF pulse
My = [0; -1; 0];
M = My;

dx = 0.003; % voxel size 
G = 1.0e-3;
T = 1/(gb * G * dx);

nsub = 16;
r = (0:(nsub-1)) * dx / nsub;

t1 = 0;
t2 = T/4;
t3 = T/2;
t4 = 3*T/4;
t5 = T;
tv = [t1, t2, t3, t4, t5];


figure; set(gcf,'color','w');
cm = parula(nsub);
for n = 1:length(tv)
    
    subplot(1,length(tv),n);
    
    smx = 0;
    smy = 0;
    for i = 1:length(r)

        phi = gb * 2 * pi * G * r(i) * tv(n);
        mx = cos(phi)*M(1) - sin(phi)*M(2);
        my = sin(phi)*M(1) + cos(phi)*M(2);
        hold on; quiver(0, 0, mx, my, 'color', cm(i,:));

        smx = smx + mx;
        smy = smy + my;

    end

    smx = smx / nsub;
    smy = smy / nsub;
    hold on; quiver(0, 0, smx, smy, 'color', 'r', 'linewidth', 2, 'maxheadsize',0.5);

    axis([-1,1,-1,1])
    axis on; 
    grid on;
    axis square;
    xlabel('$M_x$','Interpreter','latex');
    ylabel('$M_y$','Interpreter','latex');
    title(sprintf('$T=%.2f$ ms',tv(n)*1000),'Interpreter','latex')

end

%% 

M = My;

figure; set(gcf,'color','w');
cm = parula(nsub);
for n = 1:length(tv)
    
    subplot(3,length(tv),n);
    
    smx = 0;
    smy = 0;
    for i = 1:length(r)

        phi = gb * 2 * pi * G * r(i) * tv(n);
        mx = cos(phi)*M(1) - sin(phi)*M(2);
        my = sin(phi)*M(1) + cos(phi)*M(2);
        hold on; quiver(0, 0, mx, my, 'color', cm(i,:));

        smx = smx + mx;
        smy = smy + my;

    end
    smx = smx / nsub;
    smy = smy / nsub;
    hold on; quiver(0, 0, smx, smy, 'color', 'r', 'linewidth', 2, 'maxheadsize',0.5);
    axis([-1,1,-1,1])
    axis on; 
    grid on;
    axis square;
    xlabel('$M_x$','Interpreter','latex');
    ylabel('$M_y$','Interpreter','latex');
    title(sprintf('$T=%.2f$ ms',(tv(n)-T)*1000),'Interpreter','latex')


    if n == length(tv)
    subplot(3,length(tv),n+length(tv));
    smx = 0;
    smy = 0;
    for i = 1:length(r)

        phi = gb * 2 * pi * G * r(i) * tv(n);
        mx = cos(phi)*M(1) - sin(phi)*M(2);
        my = sin(phi)*M(1) + cos(phi)*M(2);
        

        phi = pi;
        my = cos(phi)*my;

        hold on; quiver(0, 0, mx, my, 'color', cm(i,:));

        smx = smx + mx;
        smy = smy + my;

    end
    smx = smx / nsub;
    smy = smy / nsub;
    hold on; quiver(0, 0, smx, smy, 'color', 'r', 'linewidth', 2, 'maxheadsize',0.5);
    axis([-1,1,-1,1])
    axis on; 
    grid on;
    axis square;
    xlabel('$M_x$','Interpreter','latex');
    ylabel('$M_y$','Interpreter','latex');
    %title(sprintf('$T=%.2f$ ms',tv(n)*1000),'Interpreter','latex')
    end 

    subplot(3,length(tv),n+2*length(tv));
    smx = 0;
    smy = 0;
    for i = 1:length(r)

        phi = gb * 2 * pi * G * r(i) * T;
        mx = cos(phi)*M(1) - sin(phi)*M(2);
        my = sin(phi)*M(1) + cos(phi)*M(2);

        phi = pi;
        my = cos(phi)*my;

        MM = [mx; my];
        phi = gb * 2 * pi * G * r(i) * tv(n);
        mx = cos(phi)*MM(1) - sin(phi)*MM(2);
        my = sin(phi)*MM(1) + cos(phi)*MM(2);

        hold on; quiver(0, 0, mx, my, 'color', cm(i,:));

        smx = smx + mx;
        smy = smy + my;

    end
    smx = smx / nsub;
    smy = smy / nsub;
    hold on; quiver(0, 0, smx, smy, 'color', 'r', 'linewidth', 2, 'maxheadsize',0.5);
    axis([-1,1,-1,1])
    axis on; 
    grid on;
    axis square;
    xlabel('$M_x$','Interpreter','latex');
    ylabel('$M_y$','Interpreter','latex');
    title(sprintf('$T=+%.2f$ ms',tv(n)*1000),'Interpreter','latex');

    
end

%% Phase Graph Figure

tau1 = 1;
tau2 = 2;
tau3 = 4.0;
m = 1;

figure; set(gcf,'color','w');

% 0 --> tau1
plot([0,tau1], [0,m*tau1], '-o', 'color', 'k');

% tau1 --> tau2 
hold on; 
plot([tau1,tau1+tau2], [m*tau1, m*tau1 + m*tau2], '-o', 'color', 'k');
hold on;
plot([tau1,tau1+tau2], [m*tau1, m*tau1 + m*tau2] -2*m*tau1, '-o', 'color', 'k');
hold on;
plot([tau1,tau1], [m*tau1, -m*tau1], '-o', 'color', 'k');
hold on; 
plot([tau1,tau1+tau2], [-m*tau1, -m*tau1], '-o', 'color', 'k');
hold on; 
plot([tau1, tau1+tau2], [0, m*tau2], '-o', 'color', 'k');
hold on; scatter(2*tau1, 0, 40, 'r', 'filled');

% tau2 --> tau3
hold on; 
plot([tau1+tau2, tau1+tau2+tau3], [0,m*tau3], '-o', 'color','k');
hold on; 
plot([tau1+tau2, tau1+tau2], [m*(tau1+tau2), -m*(tau1+tau2)], '-o', 'color','k');
hold on; 
plot([tau1+tau2, tau1+tau2+tau3], [m*(tau1+tau2), m*(tau1+tau2+tau3)], '-o', 'color', 'k');
hold on; 
plot([tau1+tau2, tau1+tau2+tau3], [-m*(tau1+tau2), m*(tau3 - tau1 -tau2)], '-o', 'color','k');
hold on; 
scatter(2*(tau1+tau2), 0, 40, 'r', 'filled');
hold on;
plot([tau1+tau2, tau1+tau2+tau3], [-m*(tau1+tau2), -m*(tau1+tau2)], '-o', 'color','k');
hold on; 
plot([tau1+tau2, tau1+tau2+tau3], [-m*tau1, m*(tau3-tau1)], '-o', 'color','k');
hold on; 
scatter(2*tau1 + tau2, 0, 40, 'r', 'filled');
hold on;
plot([tau1+tau2, tau1+tau2+tau3], [-m*tau1, -m*tau1], '-o', 'color','k');
hold on; 
plot([tau1+tau2, tau1+tau2+tau3], [-m*(tau2-tau1), -m*(tau2-tau1) + m*tau3], '-o', 'color','k');
scatter(tau1+tau2+(tau2-tau1), 0, 40, 'r', 'filled');
hold on; 
plot([tau1+tau2, tau1+tau2+tau3], [m*tau2, m*(tau2+tau3)], '-o','color','k');
hold on; 
plot([tau1+tau2, tau1+tau2+tau3], [m*(tau2-tau1), m*(tau2-tau1+tau3)], '-o','color','k');
hold on; 
plot([tau1+tau2, tau1+tau2+tau3], [-m*tau2, m*(tau3-tau2)], '-o','color','k');
scatter(tau1+2*tau2, 0, 40, 'r', 'filled');
xlabel('Time','interpreter','latex')
set(gca,'yticklabels',[],'fontsize',20);
set(gca,'ticklabelinterpreter','latex');
ylim([-3,6])


grid on;

