% «десь собраны услови€ задымленности всего кадра, движени€ во всем кадре и
% низкой освещенности

function Fails = func(Emean,EmeanEt,Imean,BKG,Elow,go)

Emax=0.5;% порог дл€ максимального количества зон с падением энергии
Mmax=0.7;% порог дл€ максимального количества зон движени€

Emean_thr=0.7;% порог падени€ средней энергии кадра
Imin=40;% нижний порог средней €ркости кадра

[asizeE,bsizeE]=size(Elow);
% таблица дл€ срабатывани€ условий
persistent Fail_table
if isempty (Fail_table)
    Fail_table=false(3,1);%1-низкое освещение кадра,2-колво движени€
end
persistent much_smoke
if isempty (much_smoke)
    much_smoke=false;%уровень задымлени€
end
%–асчет кол-ва зон
Zcount=(asizeE-1)*(bsizeE-1);
Mcount=0;
Ecount=0;

if go==1
    %ѕробег по зонам
    for i=1:asizeE
        for j=1:bsizeE
            if BKG(i,j)
                % ол-во зон c движением
                Mcount=Mcount+1;
            end
            if Elow(i,j)
                % ол-во зон c движением
                Ecount=Ecount+1;
            end
        end
    end
    
    Fail_table(2)=false;
    much_smoke = false;
    % ≈сли не темно
    if Imean > Imin
        Fail_table(1)=false;
        otnM=Mcount/Zcount;
        otnE=Ecount/Zcount;
        otnEmean=double(Emean)/double(EmeanEt);
        
        %% ƒвижение в кадре относительно эталона
        if otnM >= Mmax
            Fail_table(2)=true;
        else
            Fail_table(2)=false;
        end
        %% ƒвижение в кадре относительно эталона
        if otnEmean < Emean_thr
            if otnE >= Emax
                much_smoke=true;
            end
        else
            much_smoke=false;
        end
        
        %% ≈сли текущий кадр менее контарстен, чем  эталон
        if EmeanEt>Emean
            if otnE>Emean_thr
                otnEmean < Emean_thr
            else
                Fail_table(1)=true;
            end
        end
    end
end
Fails=false(3,1);
