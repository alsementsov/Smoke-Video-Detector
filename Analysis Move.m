function [smoke_box,start_target,table_out1,smoke_Mflag]=Tracking(zone_tab,zone_n,Blobs_count,go,Mask_Elow,Etable)

[asizeE,bsizeE]=size(Mask_Elow);
N_tar_max = 50;
N_zone_max = 1500;
Cell_size=16;
start_delta=Cell_size*5;% 3
move_elow_cross=0.6; %0.5
K_equal = double(0.45);%845
delta_blob_S = double(6);%845 порог ограничивающий резкий рост таргета
Ecentr_Th = double(0.6);

%Пороги времени жизни
TLife_H=17;%15-845
TLife_L=12;%10-845

x0 = uint8(1);
xn = uint8(2);
y0 = uint8(3);
yn = uint8(4);
zone_flag =  false(N_tar_max,1);

persistent table %ИнфТаблица
if isempty(table)
    table=double(zeros(N_tar_max, 10));
end
persistent table2 %ИнфТаблица
if isempty(table2)
    table2=double(zeros(N_tar_max, 6));
end
persistent tar_tab %Матрица таргетов
if isempty(tar_tab)
    tar_tab =  uint16(zeros(N_tar_max,N_zone_max));
end
persistent tar_start %Матрица стартовых таргетов
if isempty(tar_start)
    tar_start =  uint16(zeros(N_tar_max,N_zone_max));
end
persistent tar_flag %Флаг появления нового таргета
if isempty(tar_flag)
    tar_flag =  false(N_tar_max,1);
end
persistent tar_zone_n %Кол-во зон в таргете
if isempty(tar_zone_n)
    tar_zone_n = uint16(zeros(N_tar_max,1));
end
persistent tar_zone_n_old %Кол-во зон в старом таргете
if isempty(tar_zone_n_old)
    tar_zone_n_old = uint16(zeros(N_tar_max,1));
end
persistent tar_box %Рамка таргета на видео
if isempty(tar_box)
    tar_box =  uint16(zeros(N_tar_max,4));
end
persistent cut_zone_n %Кол-во зон в таргете с обрезанными краями
if isempty(cut_zone_n)
    cut_zone_n = uint16(zeros(N_tar_max,1));
end
persistent Ecut % Счетчик низких энергий зон в таргете с обрезаными краями
if isempty(Ecut)
    Ecut = uint16(zeros(N_tar_max,1));
end
persistent smoke_flag %Вывод сработок
if isempty(smoke_flag)
    smoke_flag = false(N_tar_max,4);
end

tar_cut_E = uint16(zeros(1,N_zone_max));
tar_cut =  uint16(zeros(1,N_zone_max));

persistent C_contr %констрастность центра
if isempty(C_contr)
    C_contr=uint16(zeros(N_tar_max,1));
end
persistent tar_box_old %Матрица старых таргетов
if isempty(tar_box_old)
    tar_box_old =  uint16(zeros(N_tar_max,4));
end
persistent tar_life %Время жизни таргета
if isempty(tar_life)
    tar_life =  uint16(zeros(N_tar_max,1));
end
persistent tar_time % Время появления таргета
if isempty(tar_time)
    tar_time =  uint32(zeros(N_tar_max,1));
end
persistent N_tar %Количество таргетов
if isempty(N_tar)
    N_tar =  int8(0);
end
persistent Targ_max %Макс количество таргетов за все время
if isempty (Targ_max)
    Targ_max=int8(1);
end
persistent Elow_counter %Счетчик совпадений маски движения и маски падения энергии
if isempty (Elow_counter)
    Elow_counter=zeros(N_tar_max,1);
end
persistent Flag_smoke %Флаг сработки таргета по условию роста
if isempty (Flag_smoke)
    Flag_smoke=false(N_tar_max,1);
end
persistent time
if isempty(time)
    time =  uint32(0);
end

equal_cnt = uint8(0);
Equal_1 = double(0);
Equal_2 = double(0);
Rise_blob = double(0);

start = uint8(0);
stop = uint8(0);

persistent tar_counter_dy %Счетчик роста таргета вверх
if isempty(tar_counter_dy)
    tar_counter_dy = uint16 (zeros(N_tar_max,1));
end;
persistent tar_counter_dy2 %Счетчик стабильной верхней границы таргета
if isempty(tar_counter_dy2)
    tar_counter_dy2 = uint16 (zeros(N_tar_max,1));
end
persistent cr_cnt
if isempty(cr_cnt)
    cr_cnt = int16 (zeros(N_tar_max,1));
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
persistent abs_sum  %845
if isempty(abs_sum)
    abs_sum = int16 (zeros(N_tar_max,1));
end
persistent tar_Area_start %Кол-во зон в таргете при появлении
if isempty(tar_Area_start)
    tar_Area_start = uint16 (zeros(N_tar_max,1));
end;
persistent start_box
if isempty(start_box)
    start_box =  uint16(zeros(N_tar_max,4));
end
persistent tar_smoke %Флаг дыма при совпадении движения и падения энергии
if isempty(tar_smoke)
    tar_smoke = false(N_tar_max,1);
end;
persistent tar_S_counter %Счетчик роста площади таргета
if isempty(tar_S_counter)
    tar_S_counter = uint16 (zeros(N_tar_max,1));
end;

%% подсчет мах количество таргетов(чтоб 50 всегда не гонять)
if Blobs_count>Targ_max
    Targ_max=int8(Blobs_count);
end
%% НАЧАЛО
if(go==1)
    time = time + 1;
    zone_flag = true (Blobs_count,1);
    %проверка совпадений + обнавление зон
    if(Blobs_count > 0)
        for m = 1: 1: Targ_max %
            %выбираем таргет
            if( tar_flag(m) == true)	% если таргет существует начинаем проверять совпадения с текущими Блобами
                tar_zone_n_old(m)= tar_zone_n(m);
                Temp_tar_tab =  tar_tab(m,:);
                temp_tar_start=tar_start(m,:);
                T_first_update=true;
                load=false;
                
                for n = 1: 1: Blobs_count  % - Перебор Блобов.
                    %считаем совпадения между Блобом и Таргетом
                    equal_cnt = 0;
                    for mm = 1: 1: tar_zone_n_old(m) % Проверяем зоны Таргета
                        for nn = 1: 1: zone_n(n) % Перебор зон Блоба на совпадение с зонами Таргета
                            if(Temp_tar_tab(1,mm) == zone_tab(n, nn))
                                equal_cnt = equal_cnt + 1;
                            end
                        end
                    end
                    
                    %считаем процентное соотношение
                    if(equal_cnt > 0)
                        Equal_1 = double(equal_cnt) /double(tar_zone_n(m)); %845
                        Equal_2 = double(equal_cnt) /double(zone_n(n)); %845
                        %Rise_blob = double(zone_n(n))/double(tar_zone_n(m)); %845
                        %if T_first_update   %845
                        %     Rise_blob=double(1);
                        % end
                        
                        if ((Equal_1 > K_equal)||(Equal_2 > K_equal)) %&& (Rise_blob <= delta_blob_S)  %845
                            if T_first_update
                                tar_zone_n(m) =0;
                                T_first_update=false;
                                tar_life(m) = tar_life(m) + 1;
                                load=true;
                            end;
                            zone_flag(n) = false;
                            %переписываем	значения
                            for mm = 1: 1: zone_n(n)
                                tar_tab(m, mm+tar_zone_n(m)) = zone_tab(n, mm);
                            end;
                            tar_start(m,:)=temp_tar_start;
                            tar_zone_n(m) =tar_zone_n(m)+zone_n(n);
                            for mm = 1: 1: zone_n(n)
                                %координаты рамки
                                zone_y =  uint16(fix(double(zone_tab(n, mm))/double(bsizeE)));
                                if fix(double(zone_tab(n,mm))/double(bsizeE))==double(zone_tab(n, mm))/double(bsizeE)
                                    zone_y=zone_y-1;
                                end
                                zone_x = uint16(zone_tab(n, mm) - zone_y*uint16(bsizeE));
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
    %% Удаление не обновившихся таргетов
    for m = 1: 1: Targ_max
        %выбираем таргет
        if(( tar_flag(m) == true)&&(tar_time(m)  < time))
            tar_flag(m) = false;
            N_tar = N_tar - 1;
            tar_life(m) = 0;
            tar_time(m) = 0;
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
    
    %% Создание новых таргетов
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
                        zone_y =  uint16(fix(double(zone_tab(n, mm))/double(bsizeE)));
                        if fix(double(zone_tab(n,mm))/double(bsizeE))==double(zone_tab(n, mm))/double(bsizeE)%833
                            zone_y=zone_y-1;
                        end
                        zone_x = uint16(zone_tab(n, mm) - zone_y*uint16(bsizeE));
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
    
    %% 845 убираем клоны таргетов     
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
    
    %% РЕШАЮЩИЙ МОДУЛЬ
    for m = 1: 1: Targ_max
        Rise_S=double(0);
        Rise_dy=double(0);
        Stab_dy=double(0);
        dRise_S=double(0);
        otnEN=double(0);
        C_contr(m)=0;
        if (tar_flag(m) == true)
            if tar_life(m) ==1
                tar_Area_start (m)=tar_zone_n(m);
                tar_counter_dy(m)=0;
                tar_counter_dy2(m)=0;
                tar_box_old(m,y0)=tar_box(m,y0);
                tar_smoke(m)=false;
                tar_S_counter(m)=0;
                abs_dy(m)=0;
                abs_dx0(m)=0;
                abs_dxn(m)=0;
                abs_sum(m)=0;
            else
                % счетчик роста площади
                if tar_zone_n(m)>=tar_zone_n_old(m)
                    tar_S_counter(m)= tar_S_counter(m)+1;
                end
                % счетчик роста верхней границы
                if tar_box(m,y0)<tar_box_old(m,y0)
                    tar_counter_dy(m)=tar_counter_dy(m)+1;
                    abs_dy(m)=abs_dy(m)+1;
                elseif tar_box(m,y0)==tar_box_old(m,y0)
                    tar_counter_dy2(m)=tar_counter_dy2(m)+1;
                    if (tar_zone_n(m)>=tar_zone_n_old(m)) && (tar_S_counter(m)>=18) && (tar_box(m,y0)==0)...%если верхняя граница == верхний край
                            || (tar_counter_dy(m)>=10&&tar_box(m,y0)==0)
                        tar_counter_dy(m)=tar_counter_dy(m)+1;
                    end
                else
                    abs_dy(m)=abs_dy(m)-1; % абсолютный рост dy
                end
                % счетчики роста боковых границ
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
                Rise_S=double(tar_zone_n(m))/double(tar_Area_start(m));
                Rise_dy=double(tar_counter_dy(m))/double(tar_life(m));
                Stab_dy=double(tar_counter_dy2(m))/double(tar_life(m));
                dRise_S=double(tar_S_counter(m))/double(tar_life(m));
                
                %% УСЛОВИЯ ДВИГАЮЩЕГОСЯ ДЫМА .................
                Flag_smoke(m)=false;            
                if tar_life(m) >=TLife_H
                    if ((Rise_S>=6) && (dRise_S>=0.6) && ((Rise_dy>=0.5) || ((Rise_dy>0.25) && ((Stab_dy>0.5) || (dRise_S>0.7)))))...%845
                            || ((Rise_S>=8) && (dRise_S>=0.4) && (Rise_dy>=0.4 || (Rise_dy>=0.2 && Stab_dy>=0.45 )))%846
                        Flag_smoke(m)=true;
                    end;
                elseif tar_life(m) >=TLife_L
                    if ((Rise_S>=8) && (dRise_S>0.7) && (Rise_dy>=0.7 || ((Rise_dy>=0.6) && ((Stab_dy>=0.4)||(dRise_S>0.8)))))%845
                        Flag_smoke(m)=true;
                    end;
                end;
                smoke_flag(m,1)=Flag_smoke(m);
               
                %% =====================ПРОВЕРКА КОНТРАСТНОСТИ В ТАРГЕТЕ=====================
                Ecut(m)=0;
                Elow_counter(m)=0;
                cut_zone_n(m)=0;
                
                if Flag_smoke(m)
                    %% Проверка контарстности внутри с Обрезкой краев таргета
                    tar_cutx=uint16(zeros(asizeE,bsizeE));
                    tar_cuty=uint16(zeros(asizeE,bsizeE));
                    %таблицы индексов
                    for mm = 1: 1: tar_zone_n(m)
                        y_label=  uint16(fix(double(tar_tab(m, mm))/double(bsizeE)));
                        x_label=  uint16(tar_tab(m, mm) -  y_label*uint16(bsizeE));
                        tar_cutx(y_label+1,x_label)=x_label;
                        tar_cuty(y_label+1,x_label)=y_label+1;
                    end
                    %перебор по строкам
                    for i=1:asizeE
                        min_x=uint16(bsizeE);
                        max_x=uint16(1);
                        for j=1:bsizeE
                            if tar_cutx(i,j)~=0
                                if tar_cutx(i,j)<min_x
                                    min_x=tar_cutx(i,j);
                                elseif tar_cutx(i,j)>max_x
                                    max_x=tar_cutx(i,j);
                                end
                            end
                        end
                        %удаление
                        for j=1:bsizeE
                            if tar_cutx(i,j)~=0
                                if tar_cutx(i,j)==min_x || tar_cutx(i,j)==max_x
                                    tar_cutx(i,j)=0;
                                end
                            end
                        end
                    end
                    %перебор по столбцам
                    for j=1:bsizeE
                        min_y=uint16(asizeE);
                        max_y=uint16(1);
                        for i=1:asizeE
                            if tar_cuty(i,j)~=0
                                if tar_cuty(i,j)<min_y
                                    min_y=tar_cuty(i,j);
                                elseif tar_cuty(i,j)>max_y
                                    max_y=tar_cuty(i,j);
                                end
                            end
                        end
                        %удаление
                        for i=1:asizeE
                            if tar_cuty(i,j)~=0
                                if tar_cuty(i,j)==min_y || tar_cuty(i,j)==max_y
                                    tar_cuty(i,j)=0;
                                end
                            end
                        end
                    end
                    %перевод из маски в индексы
                    num=uint16(0);
                    for i=1:asizeE
                        for j=1:bsizeE
                            if tar_cutx(i,j)~=0 && tar_cuty(i,j)~=0
                                num=num+1;
                                tar_cut(1,num)=j+((i-1)*bsizeE);
                            end
                        end
                    end
                    cut_zone_n(m)=num-1;
                    
                    %Анализ энергии сегментов обрезаного таргета
                    for mm=1:1:cut_zone_n(m)
                        y_label= uint16(fix(double(tar_cut(1,mm))/double(bsizeE)));
                        if fix(double(tar_cut(1,mm))/double(bsizeE))==double(tar_cut(1,mm))/double(bsizeE)%833
                            y_label=y_label-1;
                        end
                        x_label= uint16(tar_cut(1,mm)-y_label*uint16(bsizeE));
                        tar_cut_E(1,mm)=Etable(y_label+1,x_label);
                        %  Здесь была убрана закомментированная добавка++++++
                        %+++++++++++++++++++++++++++++++++
                        if tar_cut_E(1,mm)>45
                            C_contr(m)=C_contr(m)+tar_cut_E(1,mm);
                        end
                    end
                    
                    %tar_cut_E(1,:)
                    Ecentr=double(C_contr(m)/cut_zone_n(m))/100;
                    
                    if Ecentr <= Ecentr_Th %Ecut(m)>=cut_zone_n(m)
                        smoke_flag(m,2)=true;
                    else
                        smoke_flag(m,2)=false;
                    end
                    
                    %% Проверка пересечения таргета с маской Elow
                    for mm = 1: 1: tar_zone_n(m)
                        y_label= uint16(fix(double(tar_tab(m, mm))/double(bsizeE)));
                        if fix(double(tar_tab(m, mm))/double(bsizeE))==double(tar_tab(m, mm))/double(bsizeE)%833
                            y_label=y_label-1;
                        end
                        x_label= uint16(tar_tab(m, mm)-y_label*uint16(bsizeE));
                        if Mask_Elow(y_label+1,x_label)
                            Elow_counter(m)=Elow_counter(m)+1;
                        end
                    end;
                    
                    %Отношение пересечения таргета с маской Elow !!!!!!!!!!
                    otnEN=double(Elow_counter(m)/ double(tar_zone_n(m)));
                    
                    if otnEN>move_elow_cross
                        tar_smoke(m)=true;
                        smoke_flag(m,3)=true;
                    elseif otnEN>(move_elow_cross-0.15)
                        cr_cnt(m)=cr_cnt(m)+1;
                    else
                        tar_smoke(m)=false;
                        smoke_flag(m,3)=false;
                        cr_cnt(m)=int16(0);
                    end;
                    if cr_cnt(m)>=4
                        tar_smoke(m)=true;
                        smoke_flag(m,3)=true;
                    end
                    
                    if tar_smoke(m)
                        b_cnt=0;
                        for mm=1:tar_Area_start(m)%если таргет появляется снизу
                            y_label= uint16(fix(double(tar_start(m, mm))/double(bsizeE)));
                            if (y_label+2)==asizeE
                                b_cnt=b_cnt+3;
                            elseif (y_label+1)==(asizeE-1)
                                b_cnt=b_cnt+1;
                            end
                        end
                        if b_cnt>=tar_Area_start(m)
                            tar_smoke(m)=false;
                            smoke_flag(m,3)=false;
                        end
                    end
                    
                    %% Есть ли пересечения со стартовым таргетом
                    for mm = 1: tar_Area_start(m)
                        %координаты рамки
                        zone_y =  uint16(fix(double(tar_start(m, mm))/double(bsizeE)));
                        if fix(double(tar_start(m, mm))/double(bsizeE))==double(tar_start(m, mm))/double(bsizeE)%833
                            zone_y=zone_y-1;
                        end
                        zone_x = uint16(tar_start(m, mm) - zone_y*uint16(bsizeE));
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
                    
                    %центр стартового бокса
                    start_w=(start_box(m,xn)-start_box(m,x0))/2;
                    start_h=(start_box(m,yn)-start_box(m,y0))/2;
                    start_cx=start_box(m,x0)+start_w+1;
                    start_cy=start_box(m,y0)+start_h+1;
                    
                    %Пересечения по боксам с учетом Start_delta
                    if ((start_cx>=tar_box(m,x0)&&start_cx<=tar_box(m,xn))...
                            &&(start_cy>=tar_box(m,y0)&&start_cy<=tar_box(m,yn)))
                        smoke_flag(m,4)=true;
                    elseif ((abs(tar_box(m,x0)-start_cx)<=(start_w+start_delta))...
                            &&(abs(tar_box(m,xn)-start_cx)<=(start_w+start_delta)))...
                            &&((abs(tar_box(m,y0)-start_cy)<=(start_h+start_delta))...
                            &&(abs(tar_box(m,yn)-start_cy)<=(start_h+start_delta)))
                        smoke_flag(m,4)=true;
                    else
                        smoke_flag(m,4)=false;
                    end
                else
                    smoke_flag(m,:)=false;
                end
            end;
        end;
        table(m,1)  = tar_smoke(m);
        table(m,2)  = tar_life(m);
        table(m,3)  = Rise_S;
        table(m,4)  = Rise_dy;
        table(m,5)  = Stab_dy;
        table(m,6)  = dRise_S;
        table(m,7)  = abs_sum(m);
        table(m,8)  = otnEN;
    end;
end;
sum_max=int16(0);
for m=1:Targ_max
    if abs_sum(m)>sum_max
        sum_max=abs_sum(m);
    end
end
%% ВЫВОД на ЭКРАН
smoke_box=zeros(N_tar_max,4);
start_target=zeros(N_tar_max,4);

for m = 1: 1: Targ_max
    if smoke_flag(m,1) && smoke_flag(m,2) && smoke_flag(m,3) && smoke_flag(m,4)  %847
        smoke_box(m,1) = tar_box(m,x0)-15;
        smoke_box(m,2) = tar_box(m,y0)+1;
        smoke_box(m,3) = tar_box(m,xn)-15;
        smoke_box(m,4) = tar_box(m,yn)+1;
        
        start_target(m,1)=start_box(m,x0)-15;
        start_target(m,2)=start_box(m,y0)+1;
        start_target(m,3)=start_box(m,xn)-15;
        start_target(m,4)=start_box(m,yn)+1;
    end
end;

table_out1=table;
smoke_Mflag=smoke_flag;





