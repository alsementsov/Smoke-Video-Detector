function [smbox,Im_out]= fcn(box_move,start_move,smokes_Mflag,K_size,fail_t,go,box_wave,start_wave,smoke_Wflag,R,G,B,Frame)

[V,H]=size(R);
N_tar_max = 50;
W_delay = 8; %задержка выдачи  по вейвлету
lbox_height=0.5*K_size*V; %мин высота бокса если он внизу
box_height=0.2*K_size*V;%мин высота бокса если он не внизу
box_width=0.5*H;%мин ширина для низкого бокса
Th_Life = 40;

%sm_info - 1-условия роста таргета движения
%           2-неконтрастность центра таргета
%           3-есть пересечения таргета движения с маской Elow
%           4-есть пересечение со стартовым таргетом
%fail_t-1-низкое освещение кадра,
%       2-много движения,
%       3-много дыма
%smoke_sum -1- по вейвлету
%           2- по движ

smbox=uint16(zeros(N_tar_max,4));

persistent Image
if isempty(Image)
    Image=uint8(zeros(V,H,3));
end
Image(:,:,1)=R;
Image(:,:,2)=G;
Image(:,:,3)=B;

persistent Tcell %массив флагов активности Таргетов
if isempty(Tcell)
    Tcell=false(N_tar_max,1);
end
persistent TLife %массив флагов активности Таргетов
if isempty(TLife)
    TLife=uint16(zeros(N_tar_max,1));
end
persistent Tsmoke %флаг общей сработки smoke1
if isempty(Tsmoke)
    Tsmoke=false(N_tar_max,1);
end
persistent TS_start %стартовая площадь
if isempty(TS_start)
    TS_start=uint16(zeros(N_tar_max,1));
end
persistent Tbox %координаты
if isempty(Tbox)
    Tbox=uint16(zeros(N_tar_max,4));
end
persistent Tbox_start %координаты
if isempty(Tbox_start)
    Tbox_start=uint16(zeros(N_tar_max,4));
end
persistent TW_time %счетчик времени для сраб вейвлета
if isempty(TW_time)
    TW_time=uint16(zeros(N_tar_max,1));
end
persistent Tres_box %общий бокс smoke
if isempty(Tres_box)
    Tres_box =  uint16(zeros(N_tar_max,4));
end
persistent Tstart_wavelet %
if isempty(Tstart_wavelet)
    Tstart_wavelet=false(N_tar_max,1);
end

persistent txinsS %рисование SMOKE
if isempty(txinsS)
    txinsS = vision.TextInserter('Text', 'SMOKE', 'Location',  [10 120], ...
        'Color', [255 0 0], 'FontSize', 20);
end
persistent tx_Wavelet %рисование Growth (условие 1)
if isempty(tx_Wavelet)
    tx_Wavelet = vision.TextInserter('Text', 'Wavelet', 'Location',  [10 10], ...
        'Color', [0 255 0], 'FontSize', 16);
end
persistent tx_Growth %рисование Growth (условие 1)
if isempty(tx_Growth)
    tx_Growth = vision.TextInserter('Text', 'Growth', 'Location',  [10 30], ...
        'Color', [0 255 0], 'FontSize', 16);
end
persistent tx_Ecentr %рисование Ecentr (условие 2)
if isempty(tx_Ecentr)
    tx_Ecentr = vision.TextInserter('Text', 'Ecentr', 'Location',  [10 50], ...
        'Color', [0 255 0], 'FontSize', 16);
end
persistent tx_Elow %рисование Elow (условие 3)
if isempty(tx_Elow)
    tx_Elow = vision.TextInserter('Text', 'Elow', 'Location',  [10 70], ...
        'Color', [0 255 0], 'FontSize', 16);
end
persistent tx_CrossStart % рисование CrossStart (условие 4)
if isempty(tx_CrossStart)
    tx_CrossStart = vision.TextInserter('Text', 'CrossStart', 'Location',  [10 90], ...
        'Color', [0 255 0], 'FontSize', 16);
end

%% вывод из блока fails

persistent txinsI %надпись "низкая яркость"
if isempty(txinsI)
    txinsI = vision.TextInserter('Text', 'Low_Intensity', 'Location',  [10 200], ...
        'Color', [255 0 0], 'FontSize', 20);
end
persistent txinsME %надпись "много движения"
if isempty(txinsME)
    txinsME = vision.TextInserter('Text', 'Move_ Error', 'Location',  [10 250], ...
        'Color', [255 0 0], 'FontSize', 20);
end
persistent txinsSE %надпись "много дыма"
if isempty(txinsSE)
    txinsSE = vision.TextInserter('Text', 'Much_smoke', 'Location',  [10 300], ...
        'Color', [255 0 0], 'FontSize', 20);
end
fail_sw=true;

if fail_t(1)    %если низкое освещение
    fail_sw=false;
    Image=step(txinsI,Image);
end
if fail_t(2)    %если много движения
    fail_sw=false;
    Image=step(txinsME,Image);
end
if fail_t(3)    %если много дыма
    fail_sw=false;
    Image=step(txinsSE,Image);
end
new=false;
smoke_Mflag=false(N_tar_max,1);
box=uint16(zeros(1,4));
only_wavelet=false;
Twavelet_status=false(N_tar_max,1);
Tmove_status=false(N_tar_max,1);
all=false;

if go==1
    %% Цикл подготовки и очистки данных
    for m=1:N_tar_max
        smoke_Mflag(m) = smokes_Mflag(m,1) && smokes_Mflag(m,2) && smokes_Mflag(m,3) && smokes_Mflag(m,4);
        %Обнуление некоторых параметров Таргетов перед итерациями сравнения
        if ~Tcell(m)
            TS_start(m)=0;
            TW_time(m)=0;
            TLife(m)=0;
            Tsmoke(m)=false;
            Tstart_wavelet(m)=false;
             Tres_box (m,:)=  uint16(zeros(1,4));
        end;
    end;
    %%  НАСЛЕДОВАНИЕ
    for m=1:N_tar_max
        %Есть ли сработка W
        all=false;
        only_wavelet=false;
        if smoke_Wflag(m) || smoke_Mflag(m)
            if smoke_Wflag(m)
                box=box_wave(m,:);
                if smoke_Mflag(m)
                    all=true;
                else
                    only_wavelet=true;
                end;
            else
                box=uint16(box_move(m,:));
            end;
            S=(box(1,3)-box(1,1))*(box(1,4)-box(1,2));
            new=true;
            % есть ли уже такие Таргеты
            for n=1:N_tar_max
                if Tcell(n)
                    % поиск пересечений
                    flagy=false;
                    flagx=false;
                    if   box(1,2)>= Tbox(n,2)
                        if box(1,2)<= Tbox(n,4)
                            flagy=true;
                        end;
                    else
                        if Tbox(1,2)<=box(1,4)
                            flagy=true;
                        end;
                    end;
                    if box(1,1)>= Tbox(n,1)
                        if box(1,1)<= Tbox(n,3)
                            flagx=true;
                        end;
                    else
                        if Tbox(n,1)<=box(1,3)
                            flagx=true;
                        end;
                    end;
                    % если пересекаются
                    if (flagx && flagy)
                        new=false;
                        Tbox(n,:)=box(m,:);
                        if all
                            Tsmoke(n)=true;
                        else
                            if only_wavelet
                                Twavelet_status(n)=true;
                            else
                                Tmove_status(n)=true;
                            end;
                        end;
                    end
                end
                % Заполнение нового
                if new
                    flagx=true;
                    n=1;
                    % поиск пустого объекта
                    for i=1:N_tar_max
                        if (~Tcell(i)) && flagx
                            Tcell(i)=true;
                            flagx=false;
                            n=i;
                        end;
                    end;
                    TS_start(n)=S;
                    Tbox(n,:)=box(1,:);
                    Tbox_start(n,:)=box(1,:);
                    TW_time(n)=0;
                    TLife(n)=1;
                    Tsmoke(n)=false;
                    Tstart_wavelet(n)=false;
                    if all
                        Tsmoke(n)=true;
                    else
                        if only_wavelet
                            Tstart_wavelet(n)=true;%значит wavelet
                        else
                            Tstart_wavelet(n)=false;%значит move
                        end;
                    end;
                    new=false;
                end
            end
        end
    end
    
    %% ГЛАВНЫЙ ЦИКЛ с РЕШЕНИЕМ
    for m=1:N_tar_max
        if Tcell(m)
            TLife(m)=TLife(m)+1;
            S=(Tbox(m,3)-Tbox(m,1))*(Tbox(m,4)-Tbox(m,2));
            
            if Twavelet_status(m)&&Tmove_status(m)
                Tsmoke(m)=true;
            end;
            
            %% ТАЙМЕР и условия сработки
            if Tstart_wavelet(m)
                % Условие для сработки по таймеру вевлета
                if Twavelet_status(m)
                    TW_time(m)=TW_time(m)+1;%таймер отсрочки
                end;
                if (TW_time(m) > W_delay)&&(S>(0.75*TS_start(m)))
                    Tsmoke(m)=true;% ------------->SMOKE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                end;
                % Условие по сработке после ассинхронного прихода MOVE
                if Tmove_status(m)
                    Tsmoke(m)=true;
                end
            else
                if Twavelet_status(m)
                    Tsmoke(m)=true;
                end
            end;
            if ((TLife(m)>Th_Life)&&(~(Tmove_status(m)||Twavelet_status(m))))
                Tcell(m)=false;
            end;
            %Рамка
            if Tsmoke(m)
                Tres_box(m,:)=Tbox(m,:);
            else
                Tres_box(m,:)=uint16(zeros(1,4));
            end
        end;
    end;
    
    %% 851 проверка бокса по размеру, если бокс внизу и маленькая высота - сброс сработки. отдельно по smoke и presmoke
    %855 добавлена роверка по высоте и ширие объекта не на переднем плане
    %         if (smoke(m) == true) &&(res_box(m,1) ~= 0)
    %             if res_box(m,4) > (0.8*V) %
    %                 if (res_box(m,4)-res_box(m,2)) < lbox_height
    %                     smoke(m)=false;
    %                     res_box(m,:)=0;
    %                 end
    %             elseif (res_box(m,4)-res_box(m,2)) < box_height
    %                 if (res_box(m,3)-res_box(m,1)) < box_width
    %                     smoke(m)=false;
    %                     res_box(m,:)=0;
    %                 end
    %             end
    %         end
end
smoke=0;
%% SMOKE индикация
for m=1:N_tar_max
    if Tsmoke(m)
        Image=step(txinsS,Image);
        smoke=Frame
    end
    %% вспомогательная индикация
    if smoke_Wflag(m)
        Image=step(tx_Wavelet,Image);
    end
    %  Отображение сработок по движению
    if smokes_Mflag(m,1)
        Image=step(tx_Growth,Image);
    end
    if smokes_Mflag(m,2)
        Image=step(tx_Ecentr,Image);
    end
    if smokes_Mflag(m,3)
        Image=step(tx_Elow,Image);
    end
    if    (smokes_Mflag(m,1)|| smokes_Mflag(m,2) || smokes_Mflag(m,3)) && smokes_Mflag(m,4) %выводить пересечение со стартом - только если есть существенные сработки
        Image=step(tx_CrossStart,Image);
    end
end
%% Вывод данных
smbox(:,1) = Tres_box(:,1);
smbox(:,2) = Tres_box(:,2);
smbox(:,3) = Tres_box(:,3)-Tres_box(:,1);
smbox(:,4) = Tres_box(:,4)-Tres_box(:,2);
Im_out=Image;




