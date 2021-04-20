function [smoke_box,start_target,table_1,smoke_Wflag]=Tracking(zone_tab,zone_n,Label,Blobs_count,go)
[asize,bsize]=size(Label);
N_tar_max = 50;
N_zone_max = 1500;
Cell_size=16;
K_equal = double(0.45);  %845
%Пороги
TLife_ready=12;%845
TLife_slow=17;%845
Th_TimerRise = 20;

x0 = uint8(1);
xn = uint8(2);
y0 = uint8(3);
yn = uint8(4);

zone_flag =  false(N_tar_max,1); %описание зон
persistent table
if isempty(table)
    table=double(zeros(N_tar_max, 10));
end
persistent tar_tab %описание таргетов
if isempty(tar_tab)
    tar_tab =  uint16(zeros(N_tar_max,N_zone_max));
end
persistent tar_start %Матрица стартовых таргетов
if isempty(tar_start)
    tar_start =  uint16(zeros(N_tar_max,N_zone_max));
end
persistent tar_Area_start %Кол-во зон в таргете при появлении
if isempty(tar_Area_start)
    tar_Area_start = uint16 (zeros(N_tar_max,1));
end;
persistent start_box
if isempty(start_box)
    start_box =  uint16(zeros(N_tar_max,4));
end
persistent tar_flag
if isempty(tar_flag)
    tar_flag =  false(N_tar_max,1);
end
persistent tar_zone_n
if isempty(tar_zone_n)
    tar_zone_n = uint16(zeros(N_tar_max,1));
end
persistent tar_zone_n_old %Кол-во зон в старом таргете
if isempty(tar_zone_n_old)
    tar_zone_n_old = uint16(zeros(N_tar_max,1));
end
persistent tar_box
if isempty(tar_box)
    tar_box =  uint16(zeros(N_tar_max,4));
end

smoke_box = uint16(zeros(N_tar_max,4));
start_box = uint16(zeros(N_tar_max,4));

persistent tar_box_old
if isempty(tar_box_old)
    tar_box_old =  uint16(zeros(N_tar_max,4));
end
persistent tar_life
if isempty(tar_life)
    tar_life =  uint16(zeros(N_tar_max,1));
end
persistent tar_time
if isempty(tar_time)
    tar_time =  uint32(zeros(N_tar_max,1));
end
persistent N_tar
if isempty(N_tar)
    N_tar =  uint8(0);
end
persistent Targ_max
if isempty (Targ_max)
    Targ_max=int8(1);
end
persistent time
if isempty(time)
    time =  uint32(0);
end
equal_cnt = uint8(0);
Equal_1 = double(0);
Equal_2 = double(0);
Rise_blob = double(0);
tar_tab_out = uint16(zeros(N_tar_max,N_zone_max));
start = uint8(0);
stop = uint8(0);
Rise_S=double(0);
Rise_dy=double(0);
Stab_dy=double(0);

persistent Rise_counter
if isempty(Rise_counter)
    Rise_counter = uint16 (zeros(N_tar_max,1));
end;
persistent Summa_rise
if isempty(Summa_rise)
    Summa_rise = zeros(N_tar_max,1);
end;
persistent tar_counter_dy
if isempty(tar_counter_dy)
    tar_counter_dy = uint16 (zeros(N_tar_max,1));
end
persistent tar_counter_dy2
if isempty(tar_counter_dy2)
    tar_counter_dy2 = uint16 (zeros(N_tar_max,1));
end
persistent tar_S_counter %Счетчик роста площади таргета
if isempty(tar_S_counter)
    tar_S_counter = uint16 (zeros(N_tar_max,1));
end
persistent abs_dy
if isempty(abs_dy)
    abs_dy = int16 (zeros(N_tar_max,1));
end
persistent abs_dx0
if isempty(abs_dx0)
    abs_dx0 = int16 (zeros(N_tar_max,1));
end
persistent abs_dxn
if isempty(abs_dxn)
    abs_dxn = int16 (zeros(N_tar_max,1));
end
persistent abs_sum   %845
if isempty(abs_sum)
    abs_sum = int16 (zeros(N_tar_max,1));
end
persistent smoke_flag
if isempty(smoke_flag)
    smoke_flag = false(N_tar_max,1);
end;

%подсчет мах количество таргетов(чтоб 50 всегда не гонять)
if Blobs_count>Targ_max
    Targ_max=int8(Blobs_count);
end

if(go == 1)
    time = time + 1;
    zone_flag = true (Blobs_count,1);
    %% проверка совпадений + обновление зон
    if(Blobs_count > 0)
        for m = 1: 1: Targ_max %
            %выбираем таргет
            if( tar_flag(m) == true)	% если таргет существует
                tar_zone_n_old(m)= tar_zone_n(m);
                Temp_tar_tab =  tar_tab(m,:);
                temp_tar_start=tar_start(m,:);
                T_first_update=true;
                load=false;
                for n = 1: 1: Blobs_count % Перебор Блобов.
                    %считаем совпадения между Блобом и Таргетом
                    equal_cnt = 0;
                    for mm = 1: 1: tar_zone_n_old(m)
                        for nn = 1: 1: zone_n(n)
                            if(Temp_tar_tab(1, mm) == zone_tab(n, nn))
                                equal_cnt = equal_cnt + 1;
                            end
                        end % for nn = 1: 1: zone_n(n)
                    end %for mm = 1: 1: tar_zone_n(m)
                    
                    %считаем процентное соотношение
                    if(equal_cnt > 0)
                        Equal_1 = double(equal_cnt) /double(tar_zone_n(m)) ;
                        Equal_2 = double(equal_cnt) /double(zone_n(n)) ;
                        
                        if ((Equal_1 > K_equal)||(Equal_2 > K_equal))   %845
                            
                            if T_first_update
                                tar_zone_n(m) = 0;
                                T_first_update=false;
                                tar_life(m) = tar_life(m) + 1;
                                load=true;
                            end;
                            zone_flag(n) = false;
                            %переписываем	значения
                            for mm = 1: 1: zone_n(n)
                                tar_tab(m, mm+tar_zone_n(m)) = zone_tab(n, mm);     %!!!!
                            end;
                            tar_start(m,:)=temp_tar_start;
                            tar_zone_n(m) =tar_zone_n(m)+zone_n(n);
                            for mm = 1: 1: zone_n(n)
                                %координат рамки
                                zone_y =  uint16(fix(double(zone_tab(n, mm))/double(bsize)));
                                if fix(double(zone_tab(n,mm))/double(bsize))==double(zone_tab(n, mm))/double(bsize)
                                    zone_y=zone_y-1;
                                end
                                zone_x = uint16(zone_tab(n, mm) - zone_y*uint16(bsize));
                                B_yo = zone_y*Cell_size;
                                B_xo = zone_x*Cell_size;
                                B_xn=B_xo+Cell_size;
                                B_yn=B_yo+Cell_size;
                                if load
                                    tar_box(m,x0) = B_xo;
                                    tar_box(m,xn) = B_xn;
                                    tar_box(m,y0) = B_yo;
                                    tar_box(m,yn) = B_yn;
                                    load=false;
                                else
                                    if (tar_box(m,x0) > B_xo)
                                        tar_box(m,x0) = B_xo;
                                    end
                                    if (tar_box(m,xn) < B_xn)
                                        tar_box(m,xn) = B_xn;
                                    end
                                    if (tar_box(m,y0) > B_yo)
                                        tar_box(m,y0) = B_yo;
                                    end
                                    if (tar_box(m,yn) < B_yn)
                                        tar_box(m,yn) = B_yn;
                                    end
                                end
                            end
                            tar_time(m) = time;
                        end
                    end
                end
                %обнуление старых зон в таргете
                if tar_zone_n(m) < tar_zone_n_old(m)
                    start = tar_zone_n(m)+1;
                    stop = tar_zone_n_old(m);
                    for mm = start: 1: stop
                        tar_tab(m, mm) = 0;
                    end
                end
            end
        end
    end
    
    %%   удаление не обновившихся таргетов
    for m = 1: 1: Targ_max
        %выбираем таргет
        if(( tar_flag(m) == true)&&(tar_time(m)  < time))
            tar_flag(m) = false;
            N_tar = N_tar - 1;
            tar_life(m) = 0;
            tar_time(m) = 0;
            Rise_counter(m)=0;
            tar_Area_start(m)=0;
            tar_box(m,x0) = 0;
            tar_box(m,xn) = 0;
            tar_box(m,y0) = 0;
            tar_box(m,yn) = 0;
            start = 1;
            stop = tar_zone_n(m);
            tar_zone_n(m) = 0;
            for mm = start: 1: stop
                tar_tab(m, mm) = 0;
            end
            tar_start(m,:)=0;
        end
    end
    
    %% создание новых таргетов
    for n = 1: 1: Blobs_count
        if(zone_flag(n) == true)
            %ищем свободное место
            for m = 1: 1: Targ_max
                if( tar_flag(m) == false)
                    zone_flag(n) = false;
                    tar_flag(m) = true;
                    N_tar = N_tar + 1;
                    start = uint16(1);
                    stop = zone_n(n);
                    tar_zone_n(m) = zone_n(n);
                    tar_life(m) = 1;
                    tar_start(m,:)=zone_tab(n,:);
                    %переписываем	значения
                    for mm = start: 1: stop
                        tar_tab(m, mm) = zone_tab(n, mm);
                        %координаты рамки
                        zone_y =  uint16(fix(double(zone_tab(n, mm))/double(bsize)));
                        if fix(double(zone_tab(n,mm))/double(bsize))==double(zone_tab(n, mm))/double(bsize)%833
                            zone_y=zone_y-1;
                        end
                        zone_x = uint16(zone_tab(n, mm) - zone_y*uint16(bsize));
                        B_yo = zone_y*Cell_size;
                        B_xo = zone_x*Cell_size;
                        B_xn=B_xo+Cell_size;
                        B_yn=B_yo+Cell_size;
                        if mm==start
                            tar_box(m,x0) = B_xo;
                            tar_box(m,xn) = B_xn;
                            tar_box(m,y0) = B_yo;
                            tar_box(m,yn) = B_yn;
                        else
                            if (tar_box(m,x0) > B_xo)
                                tar_box(m,x0) = B_xo;
                            end
                            if (tar_box(m,xn) < B_xn)
                                tar_box(m,xn) = B_xn;
                            end
                            if (tar_box(m,y0) > B_yo)
                                tar_box(m,y0) = B_yo;
                            end
                            if (tar_box(m,yn) < B_yn)
                                tar_box(m,yn) = B_yn;
                            end
                        end
                    end
                    tar_time(m) = time;
                    break;
                end
            end
        end
    end
    
    %%   845  убираем клоны таргетов
    for m=1:1:Targ_max  %845
        for n=1:1:Targ_max
            if (tar_zone_n(m) == tar_zone_n(n)) && n~=m
                counter=0;
                for mm=1:tar_zone_n(m)
                    if tar_tab(m,mm)==tar_tab(n,mm)
                        counter=counter+1;
                    end
                end
                if counter==tar_zone_n(m)
                    if abs_sum(m)>abs_sum(n)
                        tar_box(n,:)=0;
                        tar_flag(n)=false;
                        tar_zone_n(n) = 0;
                        tar_Area_start(n) = 0;
                        tar_life(n) = 0;
                        tar_Area_start(n)=0;
                        N_tar = N_tar-1;
                    elseif tar_life(m)==tar_life(n)
                        if tar_Area_start(m) < tar_Area_start(n)
                            tar_box(n,:)=0;
                            tar_flag(n)=false;
                            tar_zone_n(n) = 0;
                            tar_Area_start(n) = 0;
                            tar_life(n) = 0;
                            tar_Area_start(n)=0;
                            N_tar = N_tar-1;
                        else
                            tar_box(m,:)=0;
                            tar_flag(m)=false;
                            tar_zone_n(m) = 0;
                            tar_Area_start(m) = 0;
                            tar_life(m) = 0;
                            tar_Area_start(m)=0;
                            N_tar = N_tar-1;
                        end
                    else
                        tar_box(m,:)=0;
                        tar_flag(m)=false;
                        tar_zone_n(m) = 0;
                        tar_Area_start(m) = 0;
                        tar_life(m) = 0;
                        tar_Area_start(m)=0;
                        N_tar = N_tar-1;
                    end
                end
            end
        end
    end
    
    %% \\\\\\\\\\\\\\\\\\\\\\Решающий модуль\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    for m = 1: 1: Targ_max
        Rise_S=double(0);
        Rise_dy=double(0);
        Stab_dy=double(0);
        dRise_S=double(0);
        
        if (tar_flag(m) == true)
            if tar_life(m) ==1
                
                %% ===========Обнуление счетчиков при старте Таргета==================
                tar_Area_start (m)=tar_zone_n(m);
                tar_counter_dy(m)=0;
                tar_counter_dy2(m)=0;
                tar_box_old(m,y0)=tar_box(m,y0);
                smoke_flag(m)=false;
                tar_S_counter(m)=0;
                abs_dy(m)=0;
                abs_dx0(m)=0;
                abs_dxn(m)=0;
                Rise_counter(m)=0;
                Summa_rise(m)=0;
            else
                if tar_zone_n(m)>=tar_zone_n_old(m)
                    tar_S_counter(m)= tar_S_counter(m)+1;
                end
                if tar_box(m,y0)<tar_box_old(m,y0)
                    tar_counter_dy(m)=tar_counter_dy(m)+1;
                    abs_dy(m)=abs_dy(m)+1;
                elseif tar_box(m,y0)==tar_box_old(m,y0)
                    tar_counter_dy2(m)=tar_counter_dy2(m)+1;
                else
                    abs_dy(m)=abs_dy(m)-1;
                end;
                %абсолютные счетчики с трех сторон
                if tar_box(m,x0)<tar_box_old(m,x0)
                    abs_dx0(m)=abs_dx0(m)+1;
                elseif tar_box(m,x0)>tar_box_old(m,x0)
                    abs_dx0(m)=abs_dx0(m)-1;
                end
                if tar_box(m,xn)>tar_box_old(m,xn)
                    abs_dxn(m)=abs_dxn(m)+1;
                elseif tar_box(m,xn)<tar_box_old(m,xn)
                    abs_dxn(m)=abs_dxn(m)-1;
                end
                abs_sum(m)=(abs_dy(m)+abs_dx0(m)+abs_dxn(m));
                tar_box_old(m,:)=tar_box(m,:);
                
                %% Проверка РОСТА !
                
                Rise_S=double(tar_zone_n(m))/double(tar_Area_start(m));
                Rise_dy=double(tar_counter_dy(m))/double(tar_life(m));
                Stab_dy=double(tar_counter_dy2(m))/double(tar_life(m));
                dRise_S=double(tar_S_counter(m))/double(tar_life(m));
                
                Th_Rise_S = tar_life(m)/4;
                   %Счетчик моментов, когда рост таргета идет с нужной скоростью
                if (Rise_S >=Th_Rise_S)&& (tar_life(m)>4)
                    Rise_counter(m) = Rise_counter(m)+1;
                end;
                % отношение счетчика роста ко времени
                div_Life_RiseCounter= double(Rise_counter(m))/double(tar_life(m));
                Summa_rise(m)=div_Life_RiseCounter+Rise_dy+Stab_dy+dRise_S;

                % ===========================УСЛОВИЕ РОСТА===========================
                smoke_flag(m)=false;
                if tar_life(m) >= TLife_ready % минимальное время жизни
                    if tar_life(m) >= TLife_slow % созревший таргет
                        if ((Rise_S>=Th_Rise_S) && (((dRise_S>=0.6) && (Rise_dy>=0.4)) || (((Rise_dy+Stab_dy)>=0.87)&&(dRise_S>=0.65)))) || ...
                                ((Rise_counter(m)>Th_TimerRise) && ((Rise_dy>=0.4) || ((Summa_rise(m)>=2.1)&&(dRise_S>=0.62)))) %(((Stab_dy+Rise_dy)>=0.75) && (dRise_S>0.65))))
                            smoke_flag(m)=true;
                        end
                    end
                    % условие быстрого существенного роста
                    if ((Rise_S>=8) && ((Rise_dy>=0.7) || ((Rise_dy>=0.45) && (Stab_dy>=0.5) && (dRise_S>0.75))))...
                            || ((Rise_S>=10) && ((Rise_dy>=0.6) || ((Rise_dy>=0.35) && (Stab_dy>=0.4) && (dRise_S>0.7))))
                        smoke_flag(m)=true;
                    end;
                end
                
                %% Cтартовый бокс
                for mm = 1: tar_Area_start(m)
                    %координаты рамки
                    zone_y =  uint16(fix(double(tar_start(m, mm))/double(bsize)));
                    if fix(double(tar_start(m, mm))/double(bsize))==double(tar_start(m, mm))/double(bsize)
                        zone_y=zone_y-1;
                    end
                    zone_x = uint16(tar_start(m, mm) - zone_y*uint16(bsize));
                    B_yo = zone_y*Cell_size;
                    B_xo = zone_x*Cell_size;
                    B_xn=B_xo+Cell_size;
                    B_yn=B_yo+Cell_size;
                    if mm==1
                        start_box(m,x0) = B_xo;
                        start_box(m,xn) = B_xn;
                        start_box(m,y0) = B_yo;
                        start_box(m,yn) = B_yn;
                    else
                        if (start_box(m,x0) > B_xo)
                            start_box(m,x0) = B_xo;
                        end
                        if (start_box(m,xn) < B_xn)
                            start_box(m,xn) = B_xn;
                        end
                        if (start_box(m,y0) > B_yo)
                            start_box(m,y0) = B_yo;
                        end
                        if (start_box(m,yn) < B_yn)
                            start_box(m,yn) = B_yn;
                        end
                    end
                end
            end;
        end;
        table(m,1)  = smoke_flag(m);
        table(m,2)  = tar_life(m);
        table(m,3)  = Rise_S;
        table(m,4)  = Rise_dy;
        table(m,5)  = Stab_dy;
        table(m,6)  = dRise_S;
        table(m,7)  = Rise_counter(m);
        table(m,8)  = Summa_rise(m);
        table(m,9)  = abs_dxn(m);
        table(m,10) = abs_dy(m)+abs_dx0(m)+abs_dxn(m);
    end;
end

%% ВЫВОД на ЭКРАН
smoke_box=uint16(zeros(N_tar_max,4));
start_target=uint16(zeros(N_tar_max,4));

for m = 1: 1: Targ_max
    if smoke_flag(m)==true
        smoke_box(m,1) = tar_box(m,x0)-15;
        smoke_box(m,2) = tar_box(m,y0)+1;
        smoke_box(m,3) = tar_box(m,xn)-15;
        smoke_box(m,4) = tar_box(m,yn)+1;
        start_target(m,1)=start_box(m,x0)-15;
        start_target(m,2)=start_box(m,y0)+1;
        start_target(m,3)=start_box(m,xn)-15;
        start_target(m,4)=start_box(m,yn)+1;
    end
end
if go==1
    m=1;
end

table_1=table;

smoke_Wflag=smoke_flag;